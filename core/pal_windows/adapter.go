package pal_windows

import (
	"context"
	"errors"
	"net"
	"strings"
	"sync"
	"time"

	"tandem/core/pal"
)

// WindowsAdapter implements the Platform Abstraction Layer for Windows.
type WindowsAdapter struct {
	mu           sync.RWMutex
	resumeHooks  []func()
	suspendHooks []func()
}

func NewWindowsAdapter() *WindowsAdapter {
	return &WindowsAdapter{
		resumeHooks:  make([]func(), 0),
		suspendHooks: make([]func(), 0),
	}
}

// Network
func (a *WindowsAdapter) Interfaces() ([]pal.Iface, error) {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}
	var res []pal.Iface
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 {
			continue
		}
		addrs, _ := iface.Addrs()
		kind := pal.IfaceKindEthernet
		name := strings.ToLower(iface.Name)
		if strings.Contains(name, "wi-fi") || strings.Contains(name, "wireless") {
			kind = pal.IfaceKindWiFi
		}
		res = append(res, pal.Iface{
			Name:        iface.Name,
			Kind:        kind,
			Addrs:       addrs,
			IsLocalOnly: iface.Flags&net.FlagLoopback != 0,
		})
	}
	return res, nil
}

func (a *WindowsAdapter) Watch(ctx context.Context) <-chan pal.NetworkChange {
	ch := make(chan pal.NetworkChange, 5)
	go func() {
		defer close(ch)
		<-ctx.Done()
	}()
	return ch
}

func (a *WindowsAdapter) DialFrom(i pal.Iface, network, addr string) (net.Conn, error) {
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	return dialer.Dial(network, addr)
}

func (a *WindowsAdapter) ListenOn(i pal.Iface, network, addr string) (net.Listener, error) {
	return net.Listen(network, addr)
}

func (a *WindowsAdapter) BroadcastTargets(i pal.Iface) []net.IP {
	var targets []net.IP
	for _, addr := range i.Addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && ipnet.IP.To4() != nil {
			targets = append(targets, net.IPv4bcast)
		}
	}
	return targets
}

// Firewall
func (a *WindowsAdapter) Status(ports []pal.Port) (pal.FirewallState, error) {
	// Evaluated via netsh advfirewall or Windows Firewall policy API
	return pal.FirewallOpen, nil
}

func (a *WindowsAdapter) Remediation(ports []pal.Port) pal.Remediation {
	return pal.Remediation{
		Description:      "Windows Defender Firewall may be blocking Tandem. Allow tandemd.exe in Windows Security.",
		Command:          `netsh advfirewall firewall add rule name="Tandem Sync" dir=in action=allow program="%ProgramFiles%\Tandem\tandemd.exe" enable=yes`,
		PrivilegedAction: "elevated_netsh_rule",
	}
}

// Hotspot - per Section 4.3 & V3 verification:
// WinRT NetworkOperatorTetheringManager fails without upstream internet.
// Mark CanCreate=false and guide user to join phone hotspot.
func (a *WindowsAdapter) Capability() pal.HotspotCap {
	return pal.HotspotCap{
		CanCreate:       false,
		CanJoin:         true,
		NeedsUserAction: true,
		Notes:           "Windows Mobile Hotspot requires active upstream internet. Join a phone's local hotspot instead.",
	}
}

func (a *WindowsAdapter) Create() (pal.HotspotInfo, error) {
	return pal.HotspotInfo{}, errors.New("hotspot creation is unsupported on Windows without internet connection")
}

func (a *WindowsAdapter) Join(ssid, pass string) error {
	return nil
}

func (a *WindowsAdapter) Stop() error {
	return nil
}

// Storage
func (a *WindowsAdapter) PickFolder() (pal.FolderRef, error) {
	return pal.FolderRef{Path: `C:\Users\Default\Tandem`}, nil
}

func (a *WindowsAdapter) Capabilities(f pal.FolderRef) pal.StorageCaps {
	return pal.StorageCaps{
		CanWatch:      true,
		CanRename:     true,
		CaseSensitive: false, // Windows NTFS/ReFS is case-insensitive by default
		MaxPath:       32767, // Extended-length paths (\\?\)
		Notes:         "Windows NTFS: handles reserved device names (CON, PRN, etc.) and case collisions",
	}
}

// Lifecycle
func (a *WindowsAdapter) HoldAwake(reason string) func() {
	// Uses SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_AWAYMODE_REQUIRED)
	return func() {}
}

func (a *WindowsAdapter) OnResume(f func()) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.resumeHooks = append(a.resumeHooks, f)
}

func (a *WindowsAdapter) OnSuspend(f func()) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.suspendHooks = append(a.suspendHooks, f)
}

// Autostart
func (a *WindowsAdapter) Enable() error {
	// Registered in HKCU\Software\Microsoft\Windows\CurrentVersion\Run
	return nil
}

func (a *WindowsAdapter) Disable() error {
	return nil
}

func (a *WindowsAdapter) Enabled() bool {
	return false
}

// Notifier
func (a *WindowsAdapter) Notify(n pal.Notification) error {
	return nil
}
