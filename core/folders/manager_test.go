package folders_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"tandem/core/folders"
	"tandem/core/trash"
)

func TestFolderManagement(t *testing.T) {
	tmpDir := t.TempDir()
	folderRoot := filepath.Join(tmpDir, "MySyncedFolder")
	_ = os.MkdirAll(folderRoot, 0755)

	trashMgr := trash.NewManager(30 * 24 * time.Hour)
	mgr := folders.NewManager(trashMgr)

	// 1. Add folder
	f, err := mgr.AddFolder("sync-1", "My Synced Folder", folderRoot, folders.TypeSendReceive, []string{"DEV-B"})
	if err != nil {
		t.Fatalf("AddFolder failed: %v", err)
	}
	if f.Type != folders.TypeSendReceive {
		t.Errorf("expected sendreceive, got %v", f.Type)
	}

	// 2. Pause folder
	paused := true
	f, err = mgr.UpdateFolder("sync-1", &paused, nil, nil)
	if err != nil || !f.Paused {
		t.Errorf("expected folder to be paused")
	}

	// 3. Detect conflicts in folder
	// Create case collision: File.txt and file.txt
	file1 := filepath.Join(folderRoot, "Document.txt")
	file2 := filepath.Join(folderRoot, "document.txt")
	_ = os.WriteFile(file1, []byte("Content A"), 0644)
	_ = os.WriteFile(file2, []byte("Content B"), 0644)

	conflicts, err := mgr.ScanConflicts("sync-1")
	if err != nil {
		t.Fatalf("ScanConflicts failed: %v", err)
	}
	if len(conflicts) != 1 {
		t.Errorf("expected 1 case collision conflict, got %d (%v)", len(conflicts), conflicts)
	}

	// 4. Safe delete through trash
	deletedItem, err := mgr.DeleteFileSafe("sync-1", "Document.txt")
	if err != nil {
		t.Fatalf("DeleteFileSafe failed: %v", err)
	}
	if deletedItem == nil {
		t.Errorf("expected trash item reference")
	}

	// Verify file is gone from folderRoot but exists in trash
	if _, err := os.Stat(file1); !os.IsNotExist(err) {
		t.Errorf("Document.txt should be moved to trash")
	}

	trashItems, _ := trashMgr.ListTrash(folderRoot)
	if len(trashItems) != 1 {
		t.Errorf("expected 1 item in trash, got %d", len(trashItems))
	}
}
