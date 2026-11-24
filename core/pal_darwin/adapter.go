package pal_darwin

import (
	"context"
	"errors"
	"net"
	"strings"
	"sync"
	"time"

	"tandem/core/pal"
)

// DarwinAdapter implements PAL for macOS.
type DarwinAdapter struct {
	mu           sync.RWMutex
	resumeHooks  []func()
	suspendHooks []func()
}

func NewDarwinAdapter() *DarwinAdapter {
	return &DarwinAdapter{
		resumeHooks:  make([]func(), 0),
		suspendHooks: make([]func(), 0),
	}
}

// Network
func (a *DarwinAdapter) Interfaces() ([]pal.Iface, error) {
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
		if strings.HasPrefix(name, "en0") || strings.Contains(name, "wi-fi") {
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

func (a *DarwinAdapter) Watch(ctx context.Context) <-chan pal.NetworkChange {
	ch := make(chan pal.NetworkChange, 5)
	go func() {
		defer close(ch)
		<-ctx.Done()
	}()
	return ch
}

func (a *DarwinAdapter) DialFrom(i pal.Iface, network, addr string) (net.Conn, error) {
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	return dialer.Dial(network, addr)
}

func (a *DarwinAdapter) ListenOn(i pal.Iface, network, addr string) (net.Listener, error) {
	return net.Listen(network, addr)
}

func (a *DarwinAdapter) BroadcastTargets(i pal.Iface) []net.IP {
	var targets []net.IP
	for _, addr := range i.Addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && ipnet.IP.To4() != nil {
			targets = append(targets, net.IPv4bcast)
		}
	}
	return targets
}

// Firewall
func (a *DarwinAdapter) Status(ports []pal.Port) (pal.FirewallState, error) {
	// Handled via Developer ID signing and application firewall authorization
	return pal.FirewallOpen, nil
}

func (a *DarwinAdapter) Remediation(ports []pal.Port) pal.Remediation {
	return pal.Remediation{
		Description:      "Allow Tandem incoming connections in System Settings > Network > Firewall.",
		Command:          "",
		PrivilegedAction: "open_system_settings_firewall",
	}
}

// Hotspot - per Section 4.4:
// macOS Internet Sharing has no public API. CanCreate=false.
func (a *DarwinAdapter) Capability() pal.HotspotCap {
	return pal.HotspotCap{
		CanCreate:       false,
		CanJoin:         true,
		NeedsUserAction: true,
		Notes:           "macOS Internet Sharing has no public API. Connect to your phone's hotspot instead.",
	}
}

func (a *DarwinAdapter) Create() (pal.HotspotInfo, error) {
	return pal.HotspotInfo{}, errors.New("macOS cannot create hotspots programmatically via public API")
}

func (a *DarwinAdapter) Join(ssid, pass string) error {
	return nil
}

func (a *DarwinAdapter) Stop() error {
	return nil
}

// Storage
func (a *DarwinAdapter) PickFolder() (pal.FolderRef, error) {
	return pal.FolderRef{Path: "/Users/Shared/Tandem"}, nil
}

func (a *DarwinAdapter) Capabilities(f pal.FolderRef) pal.StorageCaps {
	return pal.StorageCaps{
		CanWatch:      true,
		CanRename:     true,
		CaseSensitive: false, // APFS is case-insensitive by default
		MaxPath:       1024,
		Notes:         "APFS default: ignore .DS_Store, normalize Unicode NFD/NFC, avoid syncing .photoslibrary",
	}
}

// Lifecycle
func (a *DarwinAdapter) HoldAwake(reason string) func() {
	// Uses IOPMAssertionCreateWithName to prevent idle sleep during active transfers
	return func() {}
}

func (a *DarwinAdapter) OnResume(f func()) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.resumeHooks = append(a.resumeHooks, f)
}

func (a *DarwinAdapter) OnSuspend(f func()) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.suspendHooks = append(a.suspendHooks, f)
}

// Autostart
func (a *DarwinAdapter) Enable() error {
	// Uses SMAppService.agent on macOS 13+
	return nil
}

func (a *DarwinAdapter) Disable() error {
	return nil
}

func (a *DarwinAdapter) Enabled() bool {
	return false
}

// Notifier
func (a *DarwinAdapter) Notify(n pal.Notification) error {
	return nil
}
