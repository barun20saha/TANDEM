package linkmanager

import (
	"context"
	"sync"
)

// LinkMigrator coordinates dynamic path migration from relayed to direct connection without interrupting active transfers (Section 5.2 & Phase 6).
type LinkMigrator struct {
	mu           sync.RWMutex
	mgr          *Manager
	probeDirect  func(deviceID string) (string, bool)
	onMigrated   func(deviceID, newAddr string)
}

func NewLinkMigrator(
	mgr *Manager,
	probeFunc func(deviceID string) (string, bool),
	onMigrated func(deviceID, newAddr string),
) *LinkMigrator {
	return &LinkMigrator{
		mgr:         mgr,
		probeDirect: probeFunc,
		onMigrated:  onMigrated,
	}
}

// CheckAndMigrate probes all currently relayed devices to see if a direct path is now viable.
func (lm *LinkMigrator) CheckAndMigrate(ctx context.Context) int {
	lm.mu.Lock()
	defer lm.mu.Unlock()

	migratedCount := 0
	statuses := lm.mgr.AllStatuses()

	for _, s := range statuses {
		if s.State != LinkStateRelayed {
			continue
		}

		// Probe if direct connection is reachable now (e.g. NAT punch succeeded or Wi-Fi joined)
		directAddr, directPossible := lm.probeDirect(s.DeviceID)
		if directPossible && directAddr != "" {
			// Upgrade state from relayed to direct without terminating transfer
			lm.mgr.UpdateDeviceStatus(s.DeviceID, directAddr, true)
			if lm.onMigrated != nil {
				lm.onMigrated(s.DeviceID, directAddr)
			}
			migratedCount++
		}
	}

	return migratedCount
}
