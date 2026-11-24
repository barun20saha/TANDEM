package linkmanager_test

import (
	"context"
	"testing"

	"tandem/core/linkmanager"
)

func TestRelayedToDirectMigration(t *testing.T) {
	mgr := linkmanager.NewManager()

	// 1. Initial link is Relayed
	deviceID := "REMOTE-LAPTOP-1"
	relayAddr := "relay://198.51.100.1:22067/?id=RELAY-NODE"
	status := mgr.UpdateDeviceStatus(deviceID, relayAddr, true)

	if status.State != linkmanager.LinkStateRelayed {
		t.Fatalf("expected state %v, got %v", linkmanager.LinkStateRelayed, status.State)
	}

	// 2. Setup migrator with simulated direct path probe
	directReachable := false
	probeFunc := func(id string) (string, bool) {
		if directReachable {
			return "tcp://192.168.1.105:22000", true
		}
		return "", false
	}

	migratedCalled := false
	migrator := linkmanager.NewLinkMigrator(mgr, probeFunc, func(id, newAddr string) {
		migratedCalled = true
	})

	// Probe while still only relayed
	migrated := migrator.CheckAndMigrate(context.Background())
	if migrated != 0 {
		t.Errorf("expected 0 migrated devices when direct is unreachable")
	}

	// 3. Direct path becomes available (e.g., both joined same Wi-Fi or QUIC hole-punch succeeded)
	directReachable = true
	migrated = migrator.CheckAndMigrate(context.Background())
	if migrated != 1 {
		t.Fatalf("expected 1 migrated device, got %d", migrated)
	}
	if !migratedCalled {
		t.Errorf("expected onMigrated callback to be invoked")
	}

	// Verify device status is upgraded to direct-local without dropping connection
	newStatus := mgr.GetStatus(deviceID)
	if newStatus.State != linkmanager.LinkStateDirectLocal {
		t.Errorf("expected state direct-local, got %v", newStatus.State)
	}
	if newStatus.ActiveAddress != "tcp://192.168.1.105:22000" {
		t.Errorf("expected new address tcp://192.168.1.105:22000, got %s", newStatus.ActiveAddress)
	}
}
