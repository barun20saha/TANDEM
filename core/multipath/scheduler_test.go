package multipath_test

import (
	"testing"

	"tandem/core/multipath"
)

func TestMultipathBlockSchedulingAndFailover(t *testing.T) {
	sched := multipath.NewScheduler()

	// Register two network interfaces: Wi-Fi and Ethernet
	sched.AddInterface("wifi0", 20*1024*1024)     // 20 MB/s
	sched.AddInterface("eth0", 100*1024*1024)     // 100 MB/s

	// Total 10 blocks (1 MB each) to transfer
	totalBlocks := 10
	sched.InitTransfer("transfer-1", totalBlocks, 1024*1024)

	// Dispatch blocks
	assignments := sched.DispatchNextBlocks("transfer-1", 5)
	if len(assignments) != 5 {
		t.Fatalf("expected 5 assigned blocks, got %d", len(assignments))
	}

	// Verify faster interface (eth0) received proportionally more blocks
	ethCount := 0
	wifiCount := 0
	for _, a := range assignments {
		if a.IfaceName == "eth0" {
			ethCount++
		} else if a.IfaceName == "wifi0" {
			wifiCount++
		}
	}

	if ethCount <= wifiCount {
		t.Errorf("expected eth0 to receive more blocks than wifi0: eth=%d, wifi=%d", ethCount, wifiCount)
	}

	// Simulate failure on wifi0 mid-transfer: killing one interface must not corrupt the file (Phase 7 Done When)
	sched.FailInterface("wifi0")

	// In-flight blocks previously assigned to wifi0 must be safely returned to the pool
	reassigned := sched.DispatchNextBlocks("transfer-1", 5)
	for _, a := range reassigned {
		if a.IfaceName == "wifi0" {
			t.Errorf("failed interface wifi0 should not receive new blocks")
		}
		if a.IfaceName != "eth0" {
			t.Errorf("expected surviving eth0 interface to pick up remaining blocks")
		}
	}

	// Complete all blocks
	for i := 0; i < totalBlocks; i++ {
		sched.MarkBlockComplete("transfer-1", i, "eth0")
	}

	status := sched.GetTransferStatus("transfer-1")
	if !status.IsComplete {
		t.Errorf("expected transfer to complete cleanly")
	}
	if status.CompletedBlocks != totalBlocks {
		t.Errorf("expected %d completed blocks, got %d", totalBlocks, status.CompletedBlocks)
	}
}
