package chaos_test

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"

	"tandem/core/engine/compat"
	"tandem/core/linkmanager"
	"tandem/core/multipath"
	"tandem/core/trash"
)

// 1. Chaos Test: Network drop mid-transfer (Section 11.1 Scenario 7 & Phase 8)
func TestChaosNetworkDropMidTransfer(t *testing.T) {
	sched := multipath.NewScheduler()
	sched.AddInterface("wifi", 50*1024*1024)
	sched.AddInterface("cellular", 10*1024*1024)

	totalBlocks := 20
	sched.InitTransfer("chaos-job", totalBlocks, 1024*1024)

	// Dispatch initial blocks
	assignments := sched.DispatchNextBlocks("chaos-job", 10)
	if len(assignments) != 10 {
		t.Fatalf("expected 10 blocks assigned")
	}

	// Mid-transfer: Kill primary Wi-Fi interface abruptly
	sched.FailInterface("wifi")

	// Surviving cellular interface must take over remaining and dropped blocks
	reassigned := sched.DispatchNextBlocks("chaos-job", 10)
	for _, a := range reassigned {
		if a.IfaceName == "wifi" {
			t.Errorf("failed wifi interface should not be assigned blocks after failure")
		}
	}

	// Complete transfer on cellular
	for i := 0; i < totalBlocks; i++ {
		sched.MarkBlockComplete("chaos-job", i, "cellular")
	}

	status := sched.GetTransferStatus("chaos-job")
	if !status.IsComplete {
		t.Errorf("transfer should complete without data loss despite primary network failure")
	}
}

// 2. Chaos Test: Disk full during sync write (Section 4.7 Rule 3 & Phase 8)
func TestChaosDiskFullAtomicSafety(t *testing.T) {
	tmpDir := t.TempDir()
	targetFile := filepath.Join(tmpDir, "precious_data.bin")

	// Existing valid file
	originalContent := []byte("ORIGINAL_VALID_USER_CONTENT_PRESERVED")
	_ = os.WriteFile(targetFile, originalContent, 0644)

	// Simulate reader that fails with disk full (I/O error) after writing 10 bytes
	failingReader := &errorReader{
		data:       bytes.Repeat([]byte("X"), 100),
		failAfter:  10,
		errToThrow: fmt.Errorf("no space left on device: ENOSPC"),
	}

	expectedHash := fmt.Sprintf("%x", sha256.Sum256(failingReader.data))
	_, err := compat.AtomicWriteTemp(targetFile, failingReader, expectedHash)
	if err == nil {
		t.Fatalf("expected error on disk full simulation, got nil")
	}

	// Crucial invariant: Original user data must not be corrupted or overwritten!
	currentContent, err := os.ReadFile(targetFile)
	if err != nil {
		t.Fatalf("failed reading target file: %v", err)
	}
	if !bytes.Equal(currentContent, originalContent) {
		t.Errorf("original file was corrupted during partial write failure!")
	}

	// No leftover .tandem-tmp files should litter the directory
	matches, _ := filepath.Glob(filepath.Join(tmpDir, ".tandem-tmp-*"))
	if len(matches) != 0 {
		t.Errorf("leftover temporary files found after failure: %v", matches)
	}
}

// 3. Chaos Test: Recovery from accidental deletion across devices (Section 0 Rule 6 & Section 11.1 Scenario 12)
func TestChaosDeletionRecoveryFromTrash(t *testing.T) {
	tmpDir := t.TempDir()
	filePath := filepath.Join(tmpDir, "critical_project.blend")
	content := []byte("3D_MODEL_BINARY_ASSET")
	_ = os.WriteFile(filePath, content, 0644)

	tm := trash.NewManager(30 * 24 * time.Hour)

	// Intercept deletion through trash store
	item, err := tm.MoveToTrash(tmpDir, "critical_project.blend")
	if err != nil {
		t.Fatalf("MoveToTrash failed: %v", err)
	}

	if _, err := os.Stat(filePath); !os.IsNotExist(err) {
		t.Fatalf("file should not exist in active directory after deletion")
	}

	// Restore from trash
	if err := tm.RestoreFromTrash(tmpDir, item.TrashID); err != nil {
		t.Fatalf("RestoreFromTrash failed: %v", err)
	}

	recovered, err := os.ReadFile(filePath)
	if err != nil || !bytes.Equal(recovered, content) {
		t.Errorf("file was not cleanly recovered from trash: %v", err)
	}
}

// 4. Chaos Test: Sleep and resume link recovery (Section 5.5 & Section 11.1 Scenario 8)
func TestChaosSleepAndResumeRecovery(t *testing.T) {
	mgr := linkmanager.NewManager()
	deviceID := "REMOTE-PHONE"

	// Initial active link
	mgr.UpdateDeviceStatus(deviceID, "tcp://192.168.1.50:22000", true)

	// Simulate system sleep: link is dropped
	mgr.UpdateDeviceStatus(deviceID, "", false)
	status := mgr.GetStatus(deviceID)
	if status.State != linkmanager.LinkStateOffline {
		t.Errorf("expected offline state during sleep, got %v", status.State)
	}

	// Simulate resume within 2 seconds: re-announce & reconnect (Section 5.5 target)
	start := time.Now()
	mgr.UpdateDeviceStatus(deviceID, "tcp://192.168.1.50:22000", true)
	elapsed := time.Since(start)

	resumedStatus := mgr.GetStatus(deviceID)
	if resumedStatus.State != linkmanager.LinkStateDirectLocal {
		t.Errorf("expected direct-local state after resume, got %v", resumedStatus.State)
	}
	if elapsed > 2*time.Second {
		t.Errorf("reconnection exceeded 2-second recovery budget: %v", elapsed)
	}
}

type errorReader struct {
	data       []byte
	offset     int
	failAfter  int
	errToThrow error
}

func (r *errorReader) Read(p []byte) (n int, err error) {
	if r.offset >= r.failAfter {
		return 0, r.errToThrow
	}
	n = copy(p, r.data[r.offset:])
	r.offset += n
	if r.offset >= r.failAfter {
		return n, r.errToThrow
	}
	if r.offset >= len(r.data) {
		return n, io.EOF
	}
	return n, nil
}
