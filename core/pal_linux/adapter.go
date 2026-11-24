package pal_linux

import (
	"context"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"tandem/core/pal"
)

// LinuxAdapter implements all PAL interfaces for Linux platforms.
type LinuxAdapter struct {
	mu           sync.RWMutex
	resumeHooks  []func()
	suspendHooks []func()
}

func NewLinuxAdapter() *LinuxAdapter {
	return &LinuxAdapter{
		resumeHooks:  make([]func(), 0),
		suspendHooks: make([]func(), 0),
	}
}

// ================= Network =================

func (a *LinuxAdapter) Interfaces() ([]pal.Iface, error) {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil, fmt.Errorf("net.Interfaces failed: %w", err)
	}

	result := make([]pal.Iface, 0, len(ifaces))
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 {
			continue // skip down interfaces
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		kind := pal.IfaceKindEthernet
		name := strings.ToLower(iface.Name)
		if strings.HasPrefix(name, "wl") || strings.HasPrefix(name, "wlan") {
			kind = pal.IfaceKindWiFi
		} else if strings.HasPrefix(name, "usb") || strings.HasPrefix(name, "enx") {
			kind = pal.IfaceKindUSB
		} else if strings.HasPrefix(name, "lo") {
			kind = pal.IfaceKindHotspot // local loopback / isolated
		}

		result = append(result, pal.Iface{
			Name:                 iface.Name,
			Kind:                 kind,
			Addrs:                addrs,
			HasValidatedInternet: false,
			IsMetered:            false,
			IsLocalOnly:          iface.Flags&net.FlagLoopback != 0,
		})
	}
	return result, nil
}

func (a *LinuxAdapter) Watch(ctx context.Context) <-chan pal.NetworkChange {
	ch := make(chan pal.NetworkChange, 10)
	go func() {
		defer close(ch)
		ticker := time.NewTicker(3 * time.Second)
		defer ticker.Stop()

		var lastCount int
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				ifaces, err := a.Interfaces()
				if err == nil && len(ifaces) != lastCount {
					lastCount = len(ifaces)
					for _, iface := range ifaces {
						select {
						case ch <- pal.NetworkChange{
							Type:  pal.NetworkChangeAddressChange,
							Iface: iface,
						}:
						default:
						}
					}
				}
			}
		}
	}()
	return ch
}

func (a *LinuxAdapter) DialFrom(i pal.Iface, network, addr string) (net.Conn, error) {
	var localIP net.IP
	for _, a := range i.Addrs {
		if ipnet, ok := a.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if network == "tcp4" || network == "udp4" || (!strings.HasSuffix(network, "6") && ipnet.IP.To4() != nil) {
				localIP = ipnet.IP
				break
			}
		}
	}

	dialer := &net.Dialer{
		Timeout: 5 * time.Second,
	}
	if localIP != nil {
		dialer.LocalAddr = &net.TCPAddr{IP: localIP}
	}
	return dialer.Dial(network, addr)
}

func (a *LinuxAdapter) ListenOn(i pal.Iface, network, addr string) (net.Listener, error) {
	return net.Listen(network, addr)
}

func (a *LinuxAdapter) BroadcastTargets(i pal.Iface) []net.IP {
	var targets []net.IP
	for _, addr := range i.Addrs {
		ipnet, ok := addr.(*net.IPNet)
		if !ok || ipnet.IP.To4() == nil {
			continue
		}
		ip := ipnet.IP.To4()
		mask := ipnet.Mask
		if len(mask) != 4 {
			continue
		}
		broadcast := make(net.IP, 4)
		for j := 0; j < 4; j++ {
			broadcast[j] = ip[j] | ^mask[j]
		}
		targets = append(targets, broadcast)
	}
	return targets
}

// ================= Firewall =================

func (a *LinuxAdapter) Status(ports []pal.Port) (pal.FirewallState, error) {
	// 1. Check ufw
	if out, err := exec.Command("ufw", "status").CombinedOutput(); err == nil {
		s := string(out)
		if strings.Contains(s, "Status: active") {
			allAllowed := true
			for _, p := range ports {
				rule := fmt.Sprintf("%d/%s", p.Port, p.Protocol)
				if !strings.Contains(s, rule) && !strings.Contains(s, strconv.Itoa(p.Port)) {
					allAllowed = false
					break
				}
			}
			if allAllowed {
				return pal.FirewallOpen, nil
			}
			return pal.FirewallBlocked, nil
		}
		return pal.FirewallOpen, nil
	}

	// 2. Check firewalld
	if out, err := exec.Command("firewall-cmd", "--state").CombinedOutput(); err == nil {
		if strings.TrimSpace(string(out)) == "running" {
			return pal.FirewallBlocked, nil
		}
	}

	return pal.FirewallOpen, nil
}

func (a *LinuxAdapter) Remediation(ports []pal.Port) pal.Remediation {
	var cmds []string
	for _, p := range ports {
		cmds = append(cmds, fmt.Sprintf("sudo ufw allow %d/%s", p.Port, p.Protocol))
	}
	cmdStr := strings.Join(cmds, " && ")
	return pal.Remediation{
		Description:      "Your Linux firewall may block incoming peer connections. Allow Tandem sync and discovery ports.",
		Command:          cmdStr,
		PrivilegedAction: "configure_firewall_ufw",
	}
}

// ================= Hotspot =================

func (a *LinuxAdapter) Capability() pal.HotspotCap {
	out, err := exec.Command("iw", "list").CombinedOutput()
	if err == nil && strings.Contains(string(out), "AP\n") {
		return pal.HotspotCap{
			CanCreate:       true,
			CanJoin:         true,
			NeedsUserAction: false,
			Notes:           "Wi-Fi adapter supports AP mode via NetworkManager",
		}
	}
	return pal.HotspotCap{
		CanCreate:       false,
		CanJoin:         true,
		NeedsUserAction: true,
		Notes:           "No Wi-Fi interface supporting AP mode detected; join an existing hotspot instead",
	}
}

func (a *LinuxAdapter) Create() (pal.HotspotInfo, error) {
	cap := a.Capability()
	if !cap.CanCreate {
		return pal.HotspotInfo{}, fmt.Errorf("hotspot creation unsupported on this hardware")
	}

	ssid := fmt.Sprintf("Tandem-%d", time.Now().Unix()%10000)
	pass := fmt.Sprintf("tandem%d", time.Now().UnixNano()%100000000)

	cmd := exec.Command("nmcli", "device", "wifi", "hotspot", "ssid", ssid, "password", pass)
	if out, err := cmd.CombinedOutput(); err != nil {
		return pal.HotspotInfo{}, fmt.Errorf("nmcli hotspot failed: %v (output: %s)", err, string(out))
	}

	qr := fmt.Sprintf("WIFI:T:WPA;S:%s;P:%s;;", ssid, pass)
	return pal.HotspotInfo{
		SSID:       ssid,
		Passphrase: pass,
		GatewayIP:  net.ParseIP("192.168.12.1"),
		QRPayload:  qr,
	}, nil
}

func (a *LinuxAdapter) Join(ssid, pass string) error {
	cmd := exec.Command("nmcli", "device", "wifi", "connect", ssid, "password", pass)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("nmcli connect failed: %v (%s)", err, string(out))
	}
	return nil
}

func (a *LinuxAdapter) Stop() error {
	_ = exec.Command("nmcli", "connection", "down", "Hotspot").Run()
	return nil
}

// ================= Storage =================

func (a *LinuxAdapter) PickFolder() (pal.FolderRef, error) {
	// Zenity / kdialog folder picker or fallback
	if path, err := exec.LookPath("zenity"); err == nil {
		out, err := exec.Command(path, "--file-selection", "--directory", "--title=Select Folder to Sync").Output()
		if err == nil {
			p := strings.TrimSpace(string(out))
			return pal.FolderRef{ID: p, Path: p, URI: "file://" + p}, nil
		}
	}
	// Fallback to current working directory
	pwd, _ := os.Getwd()
	return pal.FolderRef{ID: pwd, Path: pwd, URI: "file://" + pwd}, nil
}

func (a *LinuxAdapter) Capabilities(f pal.FolderRef) pal.StorageCaps {
	canWatch := true
	notes := "Linux standard filesystem"

	// Check inotify watches limit
	if data, err := os.ReadFile("/proc/sys/fs/inotify/max_user_watches"); err == nil {
		limit, _ := strconv.Atoi(strings.TrimSpace(string(data)))
		if limit < 16384 {
			canWatch = false
			notes = fmt.Sprintf("inotify limit is low (%d); recommend sysctl -w fs.inotify.max_user_watches=524288", limit)
		}
	}

	return pal.StorageCaps{
		CanWatch:      canWatch,
		CanRename:     true,
		CaseSensitive: true,
		MaxPath:       4096,
		Notes:         notes,
	}
}

// ================= Lifecycle =================

func (a *LinuxAdapter) HoldAwake(reason string) func() {
	// Try systemd-inhibit if available
	ctx, cancel := context.WithCancel(context.Background())
	cmd := exec.CommandContext(ctx, "systemd-inhibit", "--what=idle:sleep", "--why="+reason, "sleep", "86400")
	_ = cmd.Start()

	return func() {
		cancel()
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
	}
}

func (a *LinuxAdapter) OnResume(f func()) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.resumeHooks = append(a.resumeHooks, f)
}

func (a *LinuxAdapter) OnSuspend(f func()) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.suspendHooks = append(a.suspendHooks, f)
}

// ================= Autostart =================

func (a *LinuxAdapter) getServicePath() string {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			home = "."
		}
		configHome = filepath.Join(home, ".config")
	}
	return filepath.Join(configHome, "systemd", "user", "tandemd.service")
}

func (a *LinuxAdapter) Enable() error {
	servicePath := a.getServicePath()
	unitDir := filepath.Dir(servicePath)
	if err := os.MkdirAll(unitDir, 0755); err != nil {
		return fmt.Errorf("create systemd user unit dir failed: %w", err)
	}

	content := `[Unit]
Description=Tandem Desktop Sync Daemon
After=network.target

[Service]
ExecStart=%h/.local/bin/tandemd
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
`
	if err := os.WriteFile(servicePath, []byte(content), 0644); err != nil {
		return fmt.Errorf("write systemd unit failed: %w", err)
	}
	_ = exec.Command("systemctl", "--user", "daemon-reload").Run()
	_ = exec.Command("systemctl", "--user", "enable", "tandemd").Run()
	return nil
}

func (a *LinuxAdapter) Disable() error {
	_ = exec.Command("systemctl", "--user", "disable", "tandemd").Run()
	servicePath := a.getServicePath()
	return os.Remove(servicePath)
}

func (a *LinuxAdapter) Enabled() bool {
	servicePath := a.getServicePath()
	_, err := os.Stat(servicePath)
	return err == nil
}

// ================= Notifier =================

func (a *LinuxAdapter) Notify(n pal.Notification) error {
	if path, err := exec.LookPath("notify-send"); err == nil {
		return exec.Command(path, n.Title, n.Body).Run()
	}
	return nil
}
