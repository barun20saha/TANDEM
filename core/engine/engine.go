package engine

import (
	"bytes"
	"context"
	"encoding/xml"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"time"
)

// EngineState represents the lifecycle status of the sync engine.
type EngineState string

const (
	EngineStateStopped  EngineState = "stopped"
	EngineStateStarting EngineState = "starting"
	EngineStateRunning  EngineState = "running"
	EngineStateError    EngineState = "error"
)

// SyncthingEngine supervises a pinned Syncthing binary and communicates over its loopback REST API.
type SyncthingEngine struct {
	config     *EngineConfig
	binaryPath string
	mu         sync.RWMutex
	state      EngineState
	cmd        *exec.Cmd
	waitDone   chan struct{}
	client     *http.Client
	myDeviceID string
	stopping   bool
	cancelCtx  context.CancelFunc
}

func ResolveBinary(explicit string) string {
	if explicit != "" {
		return explicit
	}
	binName := "syncthing"
	if runtime.GOOS == "windows" {
		binName = "syncthing.exe"
	}

	var candidates []string
	if exe, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exe)
		candidates = append(candidates,
			filepath.Join(exeDir, binName),
			filepath.Join(exeDir, "..", "Helpers", binName),
		)
	}
	candidates = append(candidates,
		filepath.Join("/tmp/tools", binName),
		filepath.Join("/usr/local/bin", binName),
		filepath.Join("/usr/bin", binName),
	)
	for _, p := range candidates {
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	if p, err := exec.LookPath(binName); err == nil {
		return p
	}
	return binName
}

func NewSyncthingEngine(cfg *EngineConfig, binaryPath string) *SyncthingEngine {
	return &SyncthingEngine{
		config:     cfg,
		binaryPath: ResolveBinary(binaryPath),
		state:      EngineStateStopped,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// EnsureIdentity generates cert.pem, key.pem, and config.xml on first run only,
// enforces 0600 permissions, and populates myDeviceID.
func (e *SyncthingEngine) EnsureIdentity() (string, error) {
	if err := e.config.EnsureDirectories(); err != nil {
		return "", err
	}

	certPath := filepath.Join(e.config.ConfigDir, "cert.pem")
	keyPath := filepath.Join(e.config.ConfigDir, "key.pem")
	cfgPath := filepath.Join(e.config.ConfigDir, "config.xml")

	_, certErr := os.Stat(certPath)
	_, keyErr := os.Stat(keyPath)
	_, cfgErr := os.Stat(cfgPath)

	if os.IsNotExist(certErr) || os.IsNotExist(keyErr) || os.IsNotExist(cfgErr) {
		cmd := exec.Command(e.binaryPath, "generate", "--home="+e.config.ConfigDir, "--no-port-probing")
		if out, err := cmd.CombinedOutput(); err != nil {
			return "", fmt.Errorf("syncthing generate failed (%s): %w\n%s", e.binaryPath, err, string(out))
		}
	}

	for _, p := range []string{certPath, keyPath, cfgPath} {
		_ = os.Chmod(p, 0600)
	}

	out, err := exec.Command(e.binaryPath, "device-id", "--home="+e.config.ConfigDir).CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("syncthing device-id failed: %w\n%s", err, string(out))
	}
	id := strings.TrimSpace(string(out))
	if id == "" {
		return "", fmt.Errorf("syncthing returned empty device-id")
	}

	if err := e.configureXML(cfgPath, id); err != nil {
		return "", fmt.Errorf("configure config.xml failed: %w", err)
	}

	e.mu.Lock()
	e.myDeviceID = id
	e.mu.Unlock()
	return id, nil
}

// configureXML patches config.xml cleanly using XML token replacement/parsing
// while preserving Syncthing's full generated schema.
func (e *SyncthingEngine) configureXML(cfgPath, myID string) error {
	raw, err := os.ReadFile(cfgPath)
	if err != nil {
		return err
	}

	apiKey := e.config.EngineAPIKey
	if apiKey == "" {
		apiKey = e.config.APIKey
	}

	minFreeTag := `<minHomeDiskFree unit="%">1</minHomeDiskFree>`
	if e.config.MinDiskFreeMB > 0 {
		minFreeTag = fmt.Sprintf(`<minHomeDiskFree unit="MB">%d</minHomeDiskFree>`, e.config.MinDiskFreeMB)
	}

	s := string(raw)
	s = replaceFirstTag(s, "address", e.config.GUIAddress)
	s = replaceFirstTag(s, "apikey", apiKey)

	// Listen addresses for BEP sync port
	listenVal := fmt.Sprintf("tcp://0.0.0.0:%d", e.config.SyncPort)
	listenQuic := fmt.Sprintf("quic://0.0.0.0:%d", e.config.SyncPort)
	s = replaceListenAddresses(s, []string{listenVal, listenQuic})

	// Options: disable Syncthing localAnnounce (tandemd discovery.Service handles UDP discoveryPort),
	// disable telemetry/crash reporting/auto-upgrade, and configure global discovery & relays per flags.
	s = replaceOptionTag(s, "globalAnnounceEnabled", fmt.Sprintf("%t", e.config.GlobalDiscovery))
	s = replaceOptionTag(s, "localAnnounceEnabled", "false")
	s = replaceOptionTag(s, "localAnnouncePort", fmt.Sprintf("%d", e.config.DiscoveryPort))
	s = replaceOptionTag(s, "relaysEnabled", fmt.Sprintf("%t", e.config.RelaysEnabled))
	s = replaceOptionTag(s, "natEnabled", fmt.Sprintf("%t", e.config.NATEnabled))
	s = replaceOptionTag(s, "startBrowser", "false")
	s = replaceOptionTag(s, "urAccepted", "-1")
	s = replaceOptionTag(s, "crashReportingEnabled", "false")
	s = replaceOptionTag(s, "autoUpgradeIntervalH", "0")
	s = replaceOptionTag(s, "reconnectionIntervalS", "2")
	s = replaceMinHomeDiskFree(s, minFreeTag)

	// Update local device name attribute if present
	if e.config.DeviceName != "" {
		oldAttr := fmt.Sprintf(`<device id="%s"`, myID)
		if idx := strings.Index(s, oldAttr); idx != -1 {
			endIdx := strings.Index(s[idx:], ">")
			if endIdx != -1 {
				seg := s[idx : idx+endIdx]
				if nIdx := strings.Index(seg, `name="`); nIdx != -1 {
					rest := seg[nIdx+6:]
					if qIdx := strings.Index(rest, `"`); qIdx != -1 {
						var esc bytes.Buffer
						_ = xml.EscapeText(&esc, []byte(e.config.DeviceName))
						newSeg := seg[:nIdx+6] + esc.String() + rest[qIdx:]
						s = s[:idx] + newSeg + s[idx+endIdx:]
					}
				}
			}
		}
	}

	return os.WriteFile(cfgPath, []byte(s), 0600)
}

func replaceFirstTag(doc, tag, value string) string {
	openTag := "<" + tag + ">"
	closeTag := "</" + tag + ">"
	i := strings.Index(doc, openTag)
	if i == -1 {
		return doc
	}
	j := strings.Index(doc[i+len(openTag):], closeTag)
	if j == -1 {
		return doc
	}
	var esc bytes.Buffer
	_ = xml.EscapeText(&esc, []byte(value))
	return doc[:i+len(openTag)] + esc.String() + doc[i+len(openTag)+j:]
}

func replaceOptionTag(doc, tag, value string) string {
	optStart := strings.Index(doc, "<options>")
	optEnd := strings.Index(doc, "</options>")
	if optStart == -1 || optEnd == -1 || optEnd <= optStart {
		return doc
	}
	opts := doc[optStart:optEnd]
	opts = replaceFirstTag(opts, tag, value)
	return doc[:optStart] + opts + doc[optEnd:]
}

func replaceListenAddresses(doc string, addrs []string) string {
	optStart := strings.Index(doc, "<options>")
	optEnd := strings.Index(doc, "</options>")
	if optStart == -1 || optEnd == -1 {
		return doc
	}
	opts := doc[optStart:optEnd]
	first := strings.Index(opts, "<listenAddress>")
	last := strings.LastIndex(opts, "</listenAddress>")
	if first == -1 || last == -1 {
		return doc
	}
	var b strings.Builder
	for i, a := range addrs {
		if i > 0 {
			b.WriteString("\n        ")
		}
		b.WriteString("<listenAddress>")
		b.WriteString(a)
		b.WriteString("</listenAddress>")
	}
	opts = opts[:first] + b.String() + opts[last+len("</listenAddress>"):]
	return doc[:optStart] + opts + doc[optEnd:]
}

func replaceMinHomeDiskFree(doc, replacement string) string {
	start := strings.Index(doc, "<minHomeDiskFree")
	endTag := "</minHomeDiskFree>"
	if start == -1 {
		return doc
	}
	end := strings.Index(doc[start:], endTag)
	if end == -1 {
		return doc
	}
	return doc[:start] + replacement + doc[start+end+len(endTag):]
}

// Start launches the supervised Syncthing process and waits until its REST API responds.
func (e *SyncthingEngine) Start(ctx context.Context) error {
	if _, err := e.EnsureIdentity(); err != nil {
		e.mu.Lock()
		e.state = EngineStateError
		e.mu.Unlock()
		return err
	}

	e.mu.Lock()
	if e.state == EngineStateRunning {
		e.mu.Unlock()
		return nil
	}
	e.state = EngineStateStarting
	e.stopping = false
	runCtx, cancel := context.WithCancel(ctx)
	e.cancelCtx = cancel
	e.mu.Unlock()

	if err := e.spawn(runCtx); err != nil {
		e.mu.Lock()
		e.state = EngineStateError
		e.mu.Unlock()
		return err
	}

	// Wait up to 15s for Syncthing REST API readiness
	deadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		if e.Ping(ctx) {
			_, _ = e.GetSystemStatus(ctx)
			e.mu.Lock()
			e.state = EngineStateRunning
			e.mu.Unlock()
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(100 * time.Millisecond):
		}
	}

	return fmt.Errorf("syncthing REST API on %s did not respond within 15s", e.config.GUIAddress)
}

func (e *SyncthingEngine) spawn(ctx context.Context) error {
	apiKey := e.config.EngineAPIKey
	if apiKey == "" {
		apiKey = e.config.APIKey
	}
	args := []string{
		"serve",
		"--home=" + e.config.ConfigDir,
		"--gui-address=" + e.config.GUIAddress,
		"--gui-apikey=" + apiKey,
		"--no-browser",
		"--no-restart",
		"--no-upgrade",
	}

	cmd := exec.Command(e.binaryPath, args...)
	cmd.Dir = e.config.ConfigDir
	setChildLifecycle(cmd)

	logFile, err := os.OpenFile(filepath.Join(e.config.ConfigDir, "syncthing.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err == nil {
		cmd.Stdout = logFile
		cmd.Stderr = logFile
	}

	if err := cmd.Start(); err != nil {
		if logFile != nil {
			_ = logFile.Close()
		}
		return fmt.Errorf("failed starting syncthing: %w", err)
	}

	doneCh := make(chan struct{})
	e.mu.Lock()
	e.cmd = cmd
	e.waitDone = doneCh
	e.mu.Unlock()

	go func(c *exec.Cmd, lf *os.File, ch chan struct{}) {
		err := c.Wait()
		close(ch)
		if lf != nil {
			_ = lf.Close()
		}
		e.mu.Lock()
		stopping := e.stopping || ctx.Err() != nil
		if !stopping {
			e.state = EngineStateError
		} else {
			e.state = EngineStateStopped
		}
		e.mu.Unlock()

		if !stopping {
			log.Printf("syncthing exited unexpectedly (%v); restarting in 1s...", err)
			select {
			case <-ctx.Done():
				return
			case <-time.After(1 * time.Second):
				if err := e.spawn(ctx); err == nil {
					e.mu.Lock()
					e.state = EngineStateRunning
					e.mu.Unlock()
				}
			}
		}
	}(cmd, logFile, doneCh)

	return nil
}

// Stop shuts down Syncthing gracefully via REST /rest/system/shutdown, falling back to SIGTERM/Kill.
func (e *SyncthingEngine) Stop() error {
	e.mu.Lock()
	e.stopping = true
	if e.cancelCtx != nil {
		e.cancelCtx()
	}
	cmd := e.cmd
	doneCh := e.waitDone
	e.state = EngineStateStopped
	e.mu.Unlock()

	if cmd == nil || cmd.Process == nil {
		return nil
	}

	// Request clean shutdown via Syncthing REST API first
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	_ = e.postJSON(ctx, "/rest/system/shutdown", nil, nil)
	cancel()

	if doneCh != nil {
		select {
		case <-doneCh:
			return nil
		case <-time.After(2500 * time.Millisecond):
		}
	}

	_ = cmd.Process.Signal(syscall.SIGTERM)
	if doneCh != nil {
		select {
		case <-doneCh:
			return nil
		case <-time.After(1 * time.Second):
		}
	}
	_ = cmd.Process.Kill()
	if doneCh != nil {
		select {
		case <-doneCh:
		case <-time.After(1 * time.Second):
		}
	}
	return nil
}

// State returns the current engine state.
func (e *SyncthingEngine) State() EngineState {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.state
}

// DeviceID returns the local Syncthing Device ID.
func (e *SyncthingEngine) DeviceID() string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.myDeviceID
}

// Config returns the active engine configuration.
func (e *SyncthingEngine) Config() *EngineConfig {
	return e.config
}
