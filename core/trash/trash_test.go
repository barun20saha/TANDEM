package trash_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"tandem/core/trash"
)

func TestTrashMoveAndRestore(t *testing.T) {
	tmpDir := t.TempDir()

	// 1. Create a user file
	userFile := filepath.Join(tmpDir, "important_doc.pdf")
	content := []byte("%PDF-1.4 test document content for recovery test")
	if err := os.WriteFile(userFile, content, 0644); err != nil {
		t.Fatal(err)
	}

	tm := trash.NewManager(30 * 24 * time.Hour) // 30 days retention

	// 2. Move file to trash instead of deleting
	item, err := tm.MoveToTrash(tmpDir, "important_doc.pdf")
	if err != nil {
		t.Fatalf("MoveToTrash failed: %v", err)
	}

	// Verify file is gone from original path
	if _, err := os.Stat(userFile); !os.IsNotExist(err) {
		t.Errorf("file should not exist at original path after trash")
	}

	// 3. List trash
	items, err := tm.ListTrash(tmpDir)
	if err != nil {
		t.Fatalf("ListTrash failed: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("expected 1 item in trash, got %d", len(items))
	}
	if items[0].OriginalPath != "important_doc.pdf" {
		t.Errorf("expected original path important_doc.pdf, got: %s", items[0].OriginalPath)
	}

	// 4. Restore file from trash
	if err := tm.RestoreFromTrash(tmpDir, item.TrashID); err != nil {
		t.Fatalf("RestoreFromTrash failed: %v", err)
	}

	// Verify file is restored with identical content
	restoredContent, err := os.ReadFile(userFile)
	if err != nil {
		t.Fatalf("failed to read restored file: %v", err)
	}
	if string(restoredContent) != string(content) {
		t.Errorf("restored content mismatch: got %q, expected %q", string(restoredContent), string(content))
	}
}

func TestTrashPurgeExpired(t *testing.T) {
	tmpDir := t.TempDir()

	file1 := filepath.Join(tmpDir, "old_file.txt")
	_ = os.WriteFile(file1, []byte("old"), 0644)

	// Manager with 1ms retention for testing expiration
	tm := trash.NewManager(1 * time.Millisecond)

	_, err := tm.MoveToTrash(tmpDir, "old_file.txt")
	if err != nil {
		t.Fatal(err)
	}

	time.Sleep(10 * time.Millisecond)

	purged, err := tm.PurgeExpired(tmpDir)
	if err != nil {
		t.Fatalf("PurgeExpired failed: %v", err)
	}
	if purged != 1 {
		t.Errorf("expected 1 purged file, got %d", purged)
	}

	items, _ := tm.ListTrash(tmpDir)
	if len(items) != 0 {
		t.Errorf("expected 0 items after purge, got %d", len(items))
	}
}
