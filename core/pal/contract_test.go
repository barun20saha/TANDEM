package pal_test

import (
	"context"
	"testing"
	"time"

	"tandem/core/pal"
)

// RunPALContractTests validates that an OS adapter satisfies the PAL contract.
func RunPALContractTests(
	t *testing.T,
	netAdapter pal.Network,
	fwAdapter pal.Firewall,
	hsAdapter pal.Hotspot,
	storageAdapter pal.Storage,
	lifecycleAdapter pal.Lifecycle,
	autostartAdapter pal.Autostart,
	notifierAdapter pal.Notifier,
) {
	t.Run("Network/Interfaces", func(t *testing.T) {
		ifaces, err := netAdapter.Interfaces()
		if err != nil {
			t.Fatalf("expected Interfaces() to succeed or return known err, got: %v", err)
		}
		for _, iface := range ifaces {
			if iface.Name == "" {
				t.Errorf("interface name must not be empty")
			}
			targets := netAdapter.BroadcastTargets(iface)
			// Broadcast targets can be empty on loopback/point-to-point, but must not panic
			_ = targets
		}
	})

	t.Run("Network/WatchContextCancellation", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		ch := netAdapter.Watch(ctx)
		cancel()

		select {
		case _, ok := <-ch:
			if ok {
				// Drained or closed is fine
			}
		case <-time.After(500 * time.Millisecond):
			t.Errorf("network watch channel did not close within 500ms after context cancellation")
		}
	})

	t.Run("Firewall/StatusAndRemediation", func(t *testing.T) {
		ports := []pal.Port{
			{Port: 22000, Protocol: "tcp"},
			{Port: 22000, Protocol: "udp"},
			{Port: 21027, Protocol: "udp"},
		}
		status, err := fwAdapter.Status(ports)
		if err != nil {
			t.Logf("firewall status check returned error: %v", err)
		}
		if status != pal.FirewallOpen && status != pal.FirewallBlocked && status != pal.FirewallUnknown {
			t.Errorf("invalid firewall status: %v", status)
		}

		remediation := fwAdapter.Remediation(ports)
		if status == pal.FirewallBlocked && remediation.Description == "" && remediation.Command == "" {
			t.Errorf("blocked firewall state must provide remediation description or command")
		}
	})

	t.Run("Hotspot/CapabilityContract", func(t *testing.T) {
		cap := hsAdapter.Capability()
		if !cap.CanCreate {
			// If unsupported, Create() MUST return an error, never fake success
			_, err := hsAdapter.Create()
			if err == nil {
				t.Errorf("Hotspot.Create() succeeded despite CanCreate being false")
			}
		}
	})

	t.Run("Storage/Capabilities", func(t *testing.T) {
		ref := pal.FolderRef{ID: "test-ref", Path: "."}
		caps := storageAdapter.Capabilities(ref)
		if caps.MaxPath <= 0 {
			t.Errorf("MaxPath must be greater than 0, got %d", caps.MaxPath)
		}
	})

	t.Run("Lifecycle/HoldAwake", func(t *testing.T) {
		release := lifecycleAdapter.HoldAwake("contract-test")
		if release == nil {
			t.Fatalf("HoldAwake must return a non-nil release func")
		}
		release()
	})

	t.Run("Autostart/EnabledContract", func(t *testing.T) {
		_ = autostartAdapter.Enabled()
	})

	t.Run("Notifier/NotifyContract", func(t *testing.T) {
		err := notifierAdapter.Notify(pal.Notification{
			Title: "Tandem Test",
			Body:  "PAL Contract notification test",
			Tag:   "test",
		})
		// Notifier should either succeed or return a clean error if desktop notification daemon is absent
		_ = err
	})
}
