package send_test

import (
	"os"
	"path/filepath"
	"testing"

	"tandem/core/send"
)

func TestSendSessionLifecycle(t *testing.T) {
	tmpDir := t.TempDir()

	// 1. Create two test files to send
	fileA := filepath.Join(tmpDir, "photo1.jpg")
	fileB := filepath.Join(tmpDir, "photo2.jpg")
	_ = os.WriteFile(fileA, []byte("JPEG_DATA_1"), 0644)
	_ = os.WriteFile(fileB, []byte("JPEG_DATA_2"), 0644)

	mgr := send.NewManager(tmpDir)

	// 2. Initiate session
	targetDevice := "TEST-DEVICE-RECIPIENT"
	session, err := mgr.CreateSession(targetDevice, []string{fileA, fileB})
	if err != nil {
		t.Fatalf("CreateSession failed: %v", err)
	}

	if session.State != send.SessionStateSending {
		t.Errorf("expected session state sending, got %v", session.State)
	}
	if session.TotalFiles != 2 {
		t.Errorf("expected total files 2, got %d", session.TotalFiles)
	}

	// 3. Verify files are staged in the ephemeral folder
	stagedA := filepath.Join(session.EphemeralFolder, "photo1.jpg")
	stagedB := filepath.Join(session.EphemeralFolder, "photo2.jpg")
	if _, err := os.Stat(stagedA); err != nil {
		t.Errorf("staged file photo1.jpg missing: %v", err)
	}
	if _, err := os.Stat(stagedB); err != nil {
		t.Errorf("staged file photo2.jpg missing: %v", err)
	}

	// 4. Mark completed and cleanup
	if err := mgr.CompleteSession(session.SessionID); err != nil {
		t.Fatalf("CompleteSession failed: %v", err)
	}

	// 5. Ephemeral directory should be removed
	if _, err := os.Stat(session.EphemeralFolder); !os.IsNotExist(err) {
		t.Errorf("ephemeral folder should be cleaned up after completion")
	}

	// Source files must remain intact
	if _, err := os.Stat(fileA); err != nil {
		t.Errorf("source file photo1.jpg was modified or deleted!")
	}
}
