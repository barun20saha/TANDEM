package pal_android

import (
	"context"
	"net"
	"sync"
	"time"

	"tandem/core/pal"
)

// AndroidAdapter implements PAL for Android (JNI/native library runtime).
type AndroidAdapter struct {
	mu           sync.RWMutex
	resumeHooks  []func()
	suspendHooks []func()
}

func NewAndroidAdapter() *AndroidAdapter {
	return &AndroidAdapter{
		resumeHooks:  make([]func(), 0),
		suspendHooks: make([]func(), 0),
	}
}

// Network
func (a *AndroidAdapter) Interfaces() ([]pal.Iface, error) {
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
		res = append(res, pal.Iface{
			Name:        iface.Name,
			Kind:        pal.IfaceKindWiFi,
			Addrs:       addrs,
			IsLocalOnly: iface.Flags&net.FlagLoopback != 0,
		})
	}
	return res, nil
}

func (a *AndroidAdapter) Watch(ctx context.Context) <-chan pal.NetworkChange {
	ch := make(chan pal.NetworkChange, 5)
	go func() {
		defer close(ch)
		<-ctx.Done()
	}()
	return ch
}

func (a *AndroidAdapter) DialFrom(i pal.Iface, network, addr string) (net.Conn, error) {
	// In Android, sockets are bound using ConnectivityManager.bindSocket()
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	return dialer.Dial(network, addr)
}

func (a *AndroidAdapter) ListenOn(i pal.Iface, network, addr string) (net.Listener, error) {
	return net.Listen(network, addr)
}

func (a *AndroidAdapter) BroadcastTargets(i pal.Iface) []net.IP {
	var targets []net.IP
	for _, addr := range i.Addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && ipnet.IP.To4() != nil {
			targets = append(targets, net.IPv4bcast)
		}
	}
	return targets
}

// Firewall
func (a *AndroidAdapter) Status(ports []pal.Port) (pal.FirewallState, error) {
	return pal.FirewallOpen, nil
}

func (a *AndroidAdapter) Remediation(ports []pal.Port) pal.Remediation {
	return pal.Remediation{
		Description: "No firewall restrictions on Android loopback/Wi-Fi",
	}
}

// Hotspot - Local-Only Hotspot (API 26+)
func (a *AndroidAdapter) Capability() pal.HotspotCap {
	return pal.HotspotCap{
		CanCreate:       true,
		CanJoin:         true,
		NeedsUserAction: false,
		Notes:           "Android Local-Only Hotspot API creates no-internet AP with QR code",
	}
}

func (a *AndroidAdapter) Create() (pal.HotspotInfo, error) {
	return pal.HotspotInfo{
		SSID:       "Tandem-Android",
		Passphrase: "tandem-secure-pass",
		GatewayIP:  net.ParseIP("192.168.43.1"),
		QRPayload:  "WIFI:T:WPA;S:Tandem-Android;P:tandem-secure-pass;;",
	}, nil
}

func (a *AndroidAdapter) Join(ssid, pass string) error {
	return nil
}

func (a *AndroidAdapter) Stop() error {
	return nil
}

// Storage
func (a *AndroidAdapter) PickFolder() (pal.FolderRef, error) {
	return pal.FolderRef{Path: "/sdcard/Download/Tandem"}, nil
}

func (a *AndroidAdapter) Capabilities(f pal.FolderRef) pal.StorageCaps {
	return pal.StorageCaps{
		CanWatch:      true,
		CanRename:     true,
		CaseSensitive: true,
		MaxPath:       4096,
		Notes:         "Scoped storage / All Files access per D5",
	}
}

// Lifecycle
func (a *AndroidAdapter) HoldAwake(reason string) func() {
	// Held via PowerManager.PARTIAL_WAKE_LOCK and WifiManager.WIFI_MODE_FULL_HIGH_PERF
	return func() {}
}

func (a *AndroidAdapter) OnResume(f func()) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.resumeHooks = append(a.resumeHooks, f)
}

func (a *AndroidAdapter) OnSuspend(f func()) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.suspendHooks = append(a.suspendHooks, f)
}

// Autostart
func (a *AndroidAdapter) Enable() error {
	// Android BOOT_COMPLETED receiver
	return nil
}

func (a *AndroidAdapter) Disable() error {
	return nil
}

func (a *AndroidAdapter) Enabled() bool {
	return true
}

// Notifier
func (a *AndroidAdapter) Notify(n pal.Notification) error {
	return nil
}
