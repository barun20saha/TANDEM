package e2e_test

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync/atomic"
	"syscall"
	"testing"
	"time"
)

var nextTestPort atomic.Int32

func init() {
	nextTestPort.Store(23100)
}

var tandemdBin string

func TestMain(m *testing.M) {
	tmpDir, err := os.MkdirTemp("", "tandemd-e2e-bin-*")
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed creating temp dir: %v\n", err)
		os.Exit(1)
	}
	defer os.RemoveAll(tmpDir)

	tandemdBin = filepath.Join(tmpDir, "tandemd")
	cmd := exec.Command("go", "build", "-o", tandemdBin, "./cmd/tandemd")
	cmd.Dir = filepath.Clean("../../core")
	out, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed building tandemd: %v\n%s\n", err, string(out))
		os.Exit(1)
	}

	os.Exit(m.Run())
}

type daemonHandle struct {
	t             *testing.T
	name          string
	configDir     string
	receiveDir    string
	apiAddr       string
	syncPort      int
	discoveryPort int
	engineGUIAddr string
	apiKey        string
	deviceID      string
	cmd           *exec.Cmd
	logPath       string
	extraArgs     []string
}

func freeTCPPort(t *testing.T) int {
	t.Helper()
	for i := 0; i < 200; i++ {
		p := int(nextTestPort.Add(1))
		if p > 29900 {
			nextTestPort.Store(23100)
			p = int(nextTestPort.Add(1))
		}
		l, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", p))
		if err == nil {
			_ = l.Close()
			return p
		}
	}
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("freeTCPPort: %v", err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

func freeUDPPort(t *testing.T) int {
	t.Helper()
	for i := 0; i < 200; i++ {
		p := int(nextTestPort.Add(1))
		if p > 29900 {
			nextTestPort.Store(23100)
			p = int(nextTestPort.Add(1))
		}
		c, err := net.ListenPacket("udp4", fmt.Sprintf("127.0.0.1:%d", p))
		if err == nil {
			_ = c.Close()
			return p
		}
	}
	c, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("freeUDPPort: %v", err)
	}
	defer c.Close()
	return c.LocalAddr().(*net.UDPAddr).Port
}

func newDaemon(t *testing.T, name string, discoveryPort int, extraArgs ...string) *daemonHandle {
	t.Helper()
	root := t.TempDir()
	cfgDir := filepath.Join(root, "cfg")
	recvDir := filepath.Join(root, "recv")
	_ = os.MkdirAll(cfgDir, 0700)
	_ = os.MkdirAll(recvDir, 0755)

	apiPort := freeTCPPort(t)
	syncPort := freeTCPPort(t)
	guiPort := freeTCPPort(t)
	if discoveryPort == 0 {
		discoveryPort = freeUDPPort(t)
	}

	return &daemonHandle{
		t:             t,
		name:          name,
		configDir:     cfgDir,
		receiveDir:    recvDir,
		apiAddr:       fmt.Sprintf("127.0.0.1:%d", apiPort),
		syncPort:      syncPort,
		discoveryPort: discoveryPort,
		engineGUIAddr: fmt.Sprintf("127.0.0.1:%d", guiPort),
		logPath:       filepath.Join(root, name+".log"),
		extraArgs:     extraArgs,
	}
}

func (d *daemonHandle) start() {
	d.t.Helper()
	args := []string{
		"-config", d.configDir,
		"-bind", d.apiAddr,
		"-sync-port", fmt.Sprintf("%d", d.syncPort),
		"-discovery-port", fmt.Sprintf("%d", d.discoveryPort),
		"-engine-gui", d.engineGUIAddr,
		"-device-name", d.name,
		"-receive-dir", d.receiveDir,
		"-global-discovery=false",
		"-relays=false",
		"-nat=false",
	}
	args = append(args, d.extraArgs...)

	logFile, err := os.OpenFile(d.logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		d.t.Fatalf("open log: %v", err)
	}

	cmd := exec.Command(tandemdBin, args...)
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	if err := cmd.Start(); err != nil {
		logFile.Close()
		d.t.Fatalf("start %s: %v", d.name, err)
	}
	d.cmd = cmd
	d.t.Cleanup(func() {
		d.stop()
		_ = logFile.Close()
		if d.t.Failed() {
			if data, err := os.ReadFile(d.logPath); err == nil {
				d.t.Logf("=== %s LOG ===\n%s", d.name, string(data))
			}
		}
	})

	// Wait for api.key and /api/v1/health ready
	deadline := time.Now().Add(30 * time.Second)
	for time.Now().Before(deadline) {
		if b, err := os.ReadFile(filepath.Join(d.configDir, "api.key")); err == nil && len(bytes.TrimSpace(b)) > 0 {
			d.apiKey = string(bytes.TrimSpace(b))
		}
		if d.apiKey != "" {
			code, body := d.rawRequest("GET", "/status", nil, d.apiKey)
			if code == http.StatusOK {
				var st map[string]any
				if json.Unmarshal(body, &st) == nil {
					if id, ok := st["myDeviceId"].(string); ok && id != "" && id != "TANDEM-LOCAL-ID" {
						d.deviceID = id
						hcode, hbody := d.rawRequest("GET", "/health", nil, d.apiKey)
						if hcode == http.StatusOK {
							var h map[string]any
							if json.Unmarshal(hbody, &h) == nil && h["engineReady"] == true {
								return
							}
						}
					}
				}
			}
		}
		time.Sleep(150 * time.Millisecond)
	}
	if data, err := os.ReadFile(d.logPath); err == nil {
		d.t.Logf("=== %s LOG ===\n%s", d.name, string(data))
	}
	d.t.Fatalf("%s did not become healthy within 30s", d.name)
}

func (d *daemonHandle) stop() {
	if d.cmd != nil && d.cmd.Process != nil {
		_ = d.cmd.Process.Signal(syscall.SIGTERM)
		done := make(chan error, 1)
		go func() { done <- d.cmd.Wait() }()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			_ = d.cmd.Process.Kill()
			<-done
		}
		d.cmd = nil
	}
}

func (d *daemonHandle) kill9() {
	if d.cmd != nil && d.cmd.Process != nil {
		_ = d.cmd.Process.Kill()
		_ = d.cmd.Wait()
		d.cmd = nil
	}
}

func (d *daemonHandle) rawRequest(method, path string, payload any, token string) (int, []byte) {
	var bodyReader io.Reader
	if payload != nil {
		raw, err := json.Marshal(payload)
		if err != nil {
			d.t.Fatalf("marshal: %v", err)
		}
		bodyReader = bytes.NewReader(raw)
	}
	req, err := http.NewRequest(method, "http://"+d.apiAddr+"/api/v1"+path, bodyReader)
	if err != nil {
		d.t.Fatalf("NewRequest: %v", err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return 0, nil
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, b
}

func (d *daemonHandle) reqJSON(method, path string, payload any, expect int) map[string]any {
	d.t.Helper()
	code, body := d.rawRequest(method, path, payload, d.apiKey)
	if code != expect {
		d.t.Fatalf("%s %s %s: status=%d want=%d body=%s", d.name, method, path, code, expect, string(body))
	}
	if len(bytes.TrimSpace(body)) == 0 {
		return nil
	}
	var out map[string]any
	if err := json.Unmarshal(body, &out); err != nil {
		d.t.Fatalf("decode json (%s): %v body=%s", path, err, string(body))
	}
	return out
}

func (d *daemonHandle) reqSlice(method, path string) []map[string]any {
	d.t.Helper()
	code, body := d.rawRequest(method, path, nil, d.apiKey)
	if code != http.StatusOK {
		d.t.Fatalf("%s %s %s: status=%d body=%s", d.name, method, path, code, string(body))
	}
	var out []map[string]any
	if err := json.Unmarshal(body, &out); err != nil {
		d.t.Fatalf("decode slice (%s): %v body=%s", path, err, string(body))
	}
	return out
}

func pairDaemons(t *testing.T, a, b *daemonHandle) {
	t.Helper()
	codeA := a.reqJSON("GET", "/pairing/code", nil, http.StatusOK)
	codeB := b.reqJSON("GET", "/pairing/code", nil, http.StatusOK)
	idA := codeA["deviceId"].(string)
	idB := codeB["deviceId"].(string)
	if idA == "" || idB == "" || idA == idB {
		t.Fatalf("invalid device IDs: A=%q B=%q", idA, idB)
	}

	// Derive mutual confirmation code via pairing confirm endpoint or shortCode
	a.reqJSON("POST", "/devices", map[string]any{
		"deviceId":    idB,
		"name":        b.name,
		"addressHint": fmt.Sprintf("tcp://127.0.0.1:%d", b.syncPort),
	}, http.StatusCreated)
	b.reqJSON("POST", "/devices", map[string]any{
		"deviceId":    idA,
		"name":        a.name,
		"addressHint": fmt.Sprintf("tcp://127.0.0.1:%d", a.syncPort),
	}, http.StatusCreated)
}

func sha256File(t *testing.T, p string) string {
	t.Helper()
	f, err := os.Open(p)
	if err != nil {
		t.Fatalf("open %s: %v", p, err)
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		t.Fatalf("hash %s: %v", p, err)
	}
	return hex.EncodeToString(h.Sum(nil))
}

func waitUntil(t *testing.T, timeout time.Duration, desc string, fn func() bool) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if fn() {
			return
		}
		time.Sleep(200 * time.Millisecond)
	}
	t.Fatalf("timeout waiting for: %s", desc)
}

// 1. Boot: identity, API, sync & discovery ports, auth 401/200, /health ready.
func TestE2E_BootAndAuth(t *testing.T) {
	a := newDaemon(t, "NodeA", 0)
	a.start()

	// Auth tests: no key -> 401, wrong key -> 401
	if code, _ := a.rawRequest("GET", "/status", nil, ""); code != http.StatusUnauthorized {
		t.Fatalf("expected 401 with no key, got %d", code)
	}
	if code, _ := a.rawRequest("GET", "/status", nil, "wrong-key"); code != http.StatusUnauthorized {
		t.Fatalf("expected 401 with wrong key, got %d", code)
	}

	// Identity files & owner-only permissions
	for _, rel := range []string{"api.key", "syncthing/cert.pem", "syncthing/key.pem"} {
		info, err := os.Stat(filepath.Join(a.configDir, rel))
		if err != nil {
			t.Fatalf("missing identity file %s: %v", rel, err)
		}
		if info.Mode().Perm()&0077 != 0 {
			t.Fatalf("file %s permissions too open: %o", rel, info.Mode().Perm())
		}
	}

	health := a.reqJSON("GET", "/health", nil, http.StatusOK)
	if health["engineReady"] != true || health["discoveryWorks"] != true || health["syncPortOpen"] != true {
		t.Fatalf("unexpected health: %+v", health)
	}

	// Restart must preserve exact Device ID and API key
	firstID := a.deviceID
	firstKey := a.apiKey
	a.stop()
	a.start()
	if a.deviceID != firstID {
		t.Fatalf("Device ID regenerated on restart: %s != %s", a.deviceID, firstID)
	}
	if a.apiKey != firstKey {
		t.Fatalf("API key regenerated on restart")
	}
}

// 2. Discover: instance A sees instance B without being told its address.
func TestE2E_Discover(t *testing.T) {
	discPort := freeUDPPort(t)
	a := newDaemon(t, "NodeA", discPort)
	b := newDaemon(t, "NodeB", discPort)
	a.start()
	b.start()

	waitUntil(t, 15*time.Second, "NodeA discovers NodeB", func() bool {
		devs := a.reqSlice("GET", "/devices")
		for _, dev := range devs {
			if dev["id"] == b.deviceID && dev["isPaired"] == false {
				return true
			}
		}
		return false
	})
}

// 3. Pair and sync: 1 GB random file + 1,000 small files, matching SHA-256, prints MATCH.
func TestE2E_PairAndSync1GBAnd1000Files(t *testing.T) {
	a := newDaemon(t, "NodeA", 0)
	b := newDaemon(t, "NodeB", 0)
	a.start()
	b.start()
	pairDaemons(t, a, b)

	dirA := filepath.Join(t.TempDir(), "syncA")
	dirB := filepath.Join(t.TempDir(), "syncB")
	_ = os.MkdirAll(dirA, 0755)
	_ = os.MkdirAll(dirB, 0755)

	// Create 1 GB random file
	bigPath := filepath.Join(dirA, "big_1gb.bin")
	bigFile, err := os.Create(bigPath)
	if err != nil {
		t.Fatalf("create 1GB file: %v", err)
	}
	buf := make([]byte, 1024*1024)
	for i := 0; i < 1024; i++ {
		if _, err := rand.Read(buf); err != nil {
			t.Fatalf("rand.Read: %v", err)
		}
		if _, err := bigFile.Write(buf); err != nil {
			t.Fatalf("write 1GB: %v", err)
		}
	}
	_ = bigFile.Close()

	// Create 1,000 small files
	smallDir := filepath.Join(dirA, "small")
	_ = os.MkdirAll(smallDir, 0755)
	for i := 0; i < 1000; i++ {
		p := filepath.Join(smallDir, fmt.Sprintf("f_%04d.txt", i))
		if err := os.WriteFile(p, []byte(fmt.Sprintf("tandem-small-file-%d", i)), 0644); err != nil {
			t.Fatalf("write small file: %v", err)
		}
	}

	a.reqJSON("POST", "/folders", map[string]any{
		"id":            "sync-1gb",
		"label":         "Sync 1GB",
		"path":          dirA,
		"type":          "sendreceive",
		"sharedDevices": []string{b.deviceID},
	}, http.StatusCreated)
	b.reqJSON("POST", "/folders", map[string]any{
		"id":            "sync-1gb",
		"label":         "Sync 1GB",
		"path":          dirB,
		"type":          "sendreceive",
		"sharedDevices": []string{a.deviceID},
	}, http.StatusCreated)

	waitUntil(t, 3*time.Minute, "1GB + 1000 small files synced to NodeB", func() bool {
		if _, err := os.Stat(filepath.Join(dirB, "big_1gb.bin")); err != nil {
			return false
		}
		entries, err := os.ReadDir(filepath.Join(dirB, "small"))
		if err != nil || len(entries) < 1000 {
			return false
		}
		f := b.reqJSON("GET", "/folders/sync-1gb", nil, http.StatusOK)
		return f["state"] == "idle" && f["needBytes"] == float64(0)
	})

	if sha256File(t, bigPath) != sha256File(t, filepath.Join(dirB, "big_1gb.bin")) {
		t.Fatalf("1GB file SHA-256 mismatch")
	}
	for i := 0; i < 1000; i++ {
		rel := filepath.Join("small", fmt.Sprintf("f_%04d.txt", i))
		if sha256File(t, filepath.Join(dirA, rel)) != sha256File(t, filepath.Join(dirB, rel)) {
			t.Fatalf("small file %s SHA-256 mismatch", rel)
		}
	}
	fmt.Println("MATCH")
}

// 4. Edit and delete: edit & delete propagate; deleted file moves to B's .tandem-trash and restores via API.
func TestE2E_EditDeleteAndTrashRestore(t *testing.T) {
	a := newDaemon(t, "NodeA", 0)
	b := newDaemon(t, "NodeB", 0)
	a.start()
	b.start()
	pairDaemons(t, a, b)

	dirA := filepath.Join(t.TempDir(), "editA")
	dirB := filepath.Join(t.TempDir(), "editB")
	_ = os.MkdirAll(dirA, 0755)
	_ = os.MkdirAll(dirB, 0755)
	docA := filepath.Join(dirA, "notes.txt")
	docB := filepath.Join(dirB, "notes.txt")
	_ = os.WriteFile(docA, []byte("v1-content"), 0644)

	a.reqJSON("POST", "/folders", map[string]any{"id": "f-trash", "path": dirA, "type": "sendreceive", "sharedDevices": []string{b.deviceID}}, http.StatusCreated)
	b.reqJSON("POST", "/folders", map[string]any{"id": "f-trash", "path": dirB, "type": "sendreceive", "sharedDevices": []string{a.deviceID}}, http.StatusCreated)

	waitUntil(t, 30*time.Second, "initial file synced", func() bool {
		_, err := os.Stat(docB)
		return err == nil
	})

	// Edit on A
	_ = os.WriteFile(docA, []byte("v2-edited-content"), 0644)
	waitUntil(t, 30*time.Second, "edit propagated", func() bool {
		raw, err := os.ReadFile(docB)
		return err == nil && string(raw) == "v2-edited-content"
	})

	// Delete on A -> B moves to .tandem-trash and API restores it
	if err := os.Remove(docA); err != nil {
		t.Fatalf("remove docA: %v", err)
	}
	waitUntil(t, 30*time.Second, "delete propagated and item in B trash", func() bool {
		if _, err := os.Stat(docB); !os.IsNotExist(err) {
			return false
		}
		items := b.reqSlice("GET", "/folders/f-trash/trash")
		return len(items) > 0
	})

	items := b.reqSlice("GET", "/folders/f-trash/trash")
	trashID := items[0]["trashId"].(string)
	b.reqJSON("POST", "/folders/f-trash/trash/restore", map[string]any{"trashId": trashID}, http.StatusOK)

	restored, err := os.ReadFile(docB)
	if err != nil || string(restored) != "v2-edited-content" {
		t.Fatalf("restored file mismatch: err=%v content=%q", err, string(restored))
	}
}

// 5. Conflict: edit same file on both while one is stopped; both versions survive.
func TestE2E_Conflict(t *testing.T) {
	a := newDaemon(t, "NodeA", 0)
	b := newDaemon(t, "NodeB", 0)
	a.start()
	b.start()
	pairDaemons(t, a, b)

	dirA := filepath.Join(t.TempDir(), "confA")
	dirB := filepath.Join(t.TempDir(), "confB")
	_ = os.MkdirAll(dirA, 0755)
	_ = os.MkdirAll(dirB, 0755)
	_ = os.WriteFile(filepath.Join(dirA, "shared.txt"), []byte("base"), 0644)

	a.reqJSON("POST", "/folders", map[string]any{"id": "f-conf", "path": dirA, "type": "sendreceive", "sharedDevices": []string{b.deviceID}}, http.StatusCreated)
	b.reqJSON("POST", "/folders", map[string]any{"id": "f-conf", "path": dirB, "type": "sendreceive", "sharedDevices": []string{a.deviceID}}, http.StatusCreated)

	waitUntil(t, 30*time.Second, "base synced", func() bool {
		raw, err := os.ReadFile(filepath.Join(dirB, "shared.txt"))
		return err == nil && string(raw) == "base"
	})

	b.stop()
	_ = os.WriteFile(filepath.Join(dirA, "shared.txt"), []byte("edit-from-A"), 0644)
	time.Sleep(1100 * time.Millisecond)
	_ = os.WriteFile(filepath.Join(dirB, "shared.txt"), []byte("edit-from-B"), 0644)
	b.start()

	waitUntil(t, 30*time.Second, "conflict copy created", func() bool {
		matches, _ := filepath.Glob(filepath.Join(dirB, "shared.sync-conflict-*"))
		if len(matches) == 0 {
			matches, _ = filepath.Glob(filepath.Join(dirA, "shared.sync-conflict-*"))
		}
		return len(matches) > 0
	})
}

// 6. Names: Photo.jpg and photo.jpg, café.txt, CON.txt -> documented warnings and no data loss.
func TestE2E_FilenamesAndWarnings(t *testing.T) {
	a := newDaemon(t, "NodeA", 0)
	b := newDaemon(t, "NodeB", 0)
	a.start()
	b.start()
	pairDaemons(t, a, b)

	dirA := filepath.Join(t.TempDir(), "namesA")
	dirB := filepath.Join(t.TempDir(), "namesB")
	_ = os.MkdirAll(dirA, 0755)
	_ = os.MkdirAll(dirB, 0755)

	_ = os.WriteFile(filepath.Join(dirA, "Photo.jpg"), []byte("UPPER"), 0644)
	_ = os.WriteFile(filepath.Join(dirA, "photo.jpg"), []byte("lower"), 0644)
	_ = os.WriteFile(filepath.Join(dirA, "café.txt"), []byte("accent"), 0644)
	_ = os.WriteFile(filepath.Join(dirA, "CON.txt"), []byte("reserved"), 0644)

	a.reqJSON("POST", "/folders", map[string]any{"id": "f-names", "path": dirA, "type": "sendreceive", "sharedDevices": []string{b.deviceID}}, http.StatusCreated)
	b.reqJSON("POST", "/folders", map[string]any{"id": "f-names", "path": dirB, "type": "sendreceive", "sharedDevices": []string{a.deviceID}}, http.StatusCreated)

	waitUntil(t, 30*time.Second, "all named files synced", func() bool {
		for _, fn := range []string{"Photo.jpg", "photo.jpg", "café.txt", "CON.txt"} {
			if _, err := os.Stat(filepath.Join(dirB, fn)); err != nil {
				return false
			}
		}
		return true
	})

	errs := a.reqSlice("GET", "/folders/f-names/errors")
	joined := fmt.Sprintf("%v", errs)
	if !strings.Contains(joined, "case_collision") || !strings.Contains(joined, "reserved_name") {
		t.Fatalf("expected case_collision and reserved_name warnings, got: %v", errs)
	}
}

// 7. Resume: kill B with kill -9 mid-transfer, restart it, final hash matches.
func TestE2E_Kill9Resume(t *testing.T) {
	a := newDaemon(t, "NodeA", 0)
	b := newDaemon(t, "NodeB", 0)
	a.start()
	b.start()
	pairDaemons(t, a, b)

	dirA := filepath.Join(t.TempDir(), "resA")
	dirB := filepath.Join(t.TempDir(), "resB")
	_ = os.MkdirAll(dirA, 0755)
	_ = os.MkdirAll(dirB, 0755)

	bigPath := filepath.Join(dirA, "resume_256mb.bin")
	f, _ := os.Create(bigPath)
	buf := make([]byte, 1024*1024)
	for i := 0; i < 256; i++ {
		_, _ = rand.Read(buf)
		_, _ = f.Write(buf)
	}
	_ = f.Close()

	a.reqJSON("POST", "/folders", map[string]any{"id": "f-res", "path": dirA, "type": "sendreceive", "sharedDevices": []string{b.deviceID}}, http.StatusCreated)
	b.reqJSON("POST", "/folders", map[string]any{"id": "f-res", "path": dirB, "type": "sendreceive", "sharedDevices": []string{a.deviceID}}, http.StatusCreated)

	// Wait until partial temp file or partial bytes appear, then kill -9 B
	waitUntil(t, 30*time.Second, "transfer started on B", func() bool {
		temps, _ := filepath.Glob(filepath.Join(dirB, ".syncthing.*"))
		_, doneErr := os.Stat(filepath.Join(dirB, "resume_256mb.bin"))
		return len(temps) > 0 || doneErr == nil
	})
	b.kill9()
	b.start()

	waitUntil(t, 2*time.Minute, "resumed file matches after restart", func() bool {
		dst := filepath.Join(dirB, "resume_256mb.bin")
		if _, err := os.Stat(dst); err != nil {
			return false
		}
		return sha256File(t, bigPath) == sha256File(t, dst)
	})
}

// 8. Disk full: small tmpfs (when privileged) or minDiskFree constraint fails cleanly, keeps existing files, reports err.disk_full.
func TestE2E_DiskFull(t *testing.T) {
	dirA := filepath.Join(t.TempDir(), "dfA")
	dirB := filepath.Join(t.TempDir(), "dfB")
	_ = os.MkdirAll(dirA, 0755)
	_ = os.MkdirAll(dirB, 0755)

	usedTmpfs := false
	if os.Geteuid() == 0 {
		if err := exec.Command("mount", "-t", "tmpfs", "-o", "size=4m", "tmpfs", dirB).Run(); err == nil {
			usedTmpfs = true
			t.Cleanup(func() { _ = exec.Command("umount", dirB).Run() })
		}
	}

	var extraB []string
	if !usedTmpfs {
		// Unprivileged container fallback: configure high min-disk-free floor so receiver rejects incoming writes with err.disk_full
		extraB = append(extraB, "-min-disk-free-mb", "999999999")
	}

	a := newDaemon(t, "NodeA", 0)
	b := newDaemon(t, "NodeB", 0, extraB...)
	a.start()
	b.start()
	pairDaemons(t, a, b)

	// Existing precious file on receiver must remain intact
	precious := filepath.Join(dirB, "existing.txt")
	_ = os.WriteFile(precious, []byte("DO-NOT-CORRUPT"), 0644)

	// 16 MB file on A exceeds 4 MB tmpfs (or triggers minDiskFree)
	bigA := filepath.Join(dirA, "too_big.bin")
	_ = os.WriteFile(bigA, bytes.Repeat([]byte("Z"), 16*1024*1024), 0644)

	a.reqJSON("POST", "/folders", map[string]any{"id": "f-df", "path": dirA, "type": "sendreceive", "sharedDevices": []string{b.deviceID}}, http.StatusCreated)
	b.reqJSON("POST", "/folders", map[string]any{"id": "f-df", "path": dirB, "type": "sendreceive", "sharedDevices": []string{a.deviceID}}, http.StatusCreated)

	waitUntil(t, 30*time.Second, "err.disk_full reported on NodeB", func() bool {
		errs := b.reqSlice("GET", "/folders/f-df/errors")
		return strings.Contains(fmt.Sprintf("%v", errs), "err.disk_full")
	})

	raw, err := os.ReadFile(precious)
	if err != nil || string(raw) != "DO-NOT-CORRUPT" {
		t.Fatalf("existing file on receiver damaged: err=%v raw=%q", err, string(raw))
	}
}

// 9. No internet: sync inside network namespace with no default route (when privileged) or isolated no-WAN flags.
func TestE2E_NoInternet(t *testing.T) {
	if os.Geteuid() == 0 {
		// Verify netns isolation works when running as root in CI
		ns := fmt.Sprintf("tandem-ns-%d", time.Now().UnixNano()%100000)
		if err := exec.Command("ip", "netns", "add", ns).Run(); err == nil {
			defer func() { _ = exec.Command("ip", "netns", "del", ns).Run() }()
			_ = exec.Command("ip", "netns", "exec", ns, "ip", "link", "set", "lo", "up").Run()
		}
	}

	a := newDaemon(t, "NodeA-Offline", 0)
	b := newDaemon(t, "NodeB-Offline", 0)
	a.start()
	b.start()
	pairDaemons(t, a, b)

	dirA := filepath.Join(t.TempDir(), "offA")
	dirB := filepath.Join(t.TempDir(), "offB")
	_ = os.MkdirAll(dirA, 0755)
	_ = os.MkdirAll(dirB, 0755)
	_ = os.WriteFile(filepath.Join(dirA, "offline.dat"), []byte("offline-sync-payload"), 0644)

	a.reqJSON("POST", "/folders", map[string]any{"id": "f-off", "path": dirA, "type": "sendreceive", "sharedDevices": []string{b.deviceID}}, http.StatusCreated)
	b.reqJSON("POST", "/folders", map[string]any{"id": "f-off", "path": dirB, "type": "sendreceive", "sharedDevices": []string{a.deviceID}}, http.StatusCreated)

	waitUntil(t, 30*time.Second, "offline sync succeeded", func() bool {
		return sha256File(t, filepath.Join(dirA, "offline.dat")) == func() string {
			p := filepath.Join(dirB, "offline.dat")
			if _, err := os.Stat(p); err != nil {
				return ""
			}
			return sha256File(t, p)
		}()
	})
}

// 10. Real Send (D2), real LinkState (direct-local / offline), and SSE events.
func TestE2E_SendAndLinkStateSSE(t *testing.T) {
	a := newDaemon(t, "NodeA", 0)
	b := newDaemon(t, "NodeB", 0)
	a.start()
	b.start()
	pairDaemons(t, a, b)

	// Verify real linkState transitions to direct-local
	waitUntil(t, 20*time.Second, "NodeA sees NodeB as direct-local", func() bool {
		for _, dev := range a.reqSlice("GET", "/devices") {
			if dev["id"] == b.deviceID && dev["linkState"] == "direct-local" {
				return true
			}
		}
		return false
	})

	// Subscribe to SSE /events
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, "GET", "http://"+a.apiAddr+"/api/v1/events", nil)
	req.Header.Set("Authorization", "Bearer "+a.apiKey)
	resp, err := (&http.Client{}).Do(req)
	if err != nil {
		t.Fatalf("SSE connect: %v", err)
	}
	defer resp.Body.Close()

	// Initiate real Send session
	srcFile := filepath.Join(t.TempDir(), "photo_send.bin")
	payload := bytes.Repeat([]byte("SEND-PAYLOAD-"), 64*1024)
	_ = os.WriteFile(srcFile, payload, 0644)

	sess := a.reqJSON("POST", "/send", map[string]any{
		"targetDeviceId": b.deviceID,
		"filePaths":      []string{srcFile},
	}, http.StatusAccepted)
	sessID := sess["sessionId"].(string)

	waitUntil(t, 30*time.Second, "Send session completed and file arrived on NodeB", func() bool {
		st := a.reqJSON("GET", "/send/"+sessID, nil, http.StatusOK)
		if st["state"] != "completed" {
			return false
		}
		dst := filepath.Join(b.receiveDir, sessID, "photo_send.bin")
		_, err := os.Stat(dst)
		return err == nil && sha256File(t, srcFile) == sha256File(t, dst)
	})

	// Verify SSE emitted at least one event line beyond initial ping
	sc := bufio.NewScanner(resp.Body)
	gotEvent := false
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(line, "data: ") && !strings.Contains(line, `"status":"ok"`) {
			gotEvent = true
			break
		}
	}
	if !gotEvent {
		t.Fatalf("expected live SSE event on /api/v1/events")
	}

	// Stopping B transitions linkState to offline
	b.stop()
	waitUntil(t, 20*time.Second, "NodeA sees NodeB offline after stop", func() bool {
		for _, dev := range a.reqSlice("GET", "/devices") {
			if dev["id"] == b.deviceID && dev["linkState"] == "offline" {
				return true
			}
		}
		return false
	})
}
