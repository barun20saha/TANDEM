package trash

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const (
	TrashDirName     = ".tandem-trash"
	ManifestFileName = "manifest.json"
)

// TrashItem records a deleted or overwritten file preserved in the trash store.
type TrashItem struct {
	TrashID      string    `json:"trashId"`
	OriginalPath string    `json:"originalPath"`
	DeletedAt    time.Time `json:"deletedAt"`
	SizeBytes    int64     `json:"sizeBytes"`
}

// Manager governs trash storage, 30-day retention, and recovery (Rule 6).
type Manager struct {
	mu           sync.RWMutex
	retentionDur time.Duration
}

func NewManager(retention time.Duration) *Manager {
	if retention <= 0 {
		retention = 30 * 24 * time.Hour // Default: 30 days
	}
	return &Manager{
		retentionDur: retention,
	}
}

func (m *Manager) getTrashDir(folderRoot string) string {
	return filepath.Join(folderRoot, TrashDirName)
}

func (m *Manager) readManifest(trashDir string) ([]TrashItem, error) {
	manifestPath := filepath.Join(trashDir, ManifestFileName)
	data, err := os.ReadFile(manifestPath)
	if os.IsNotExist(err) {
		return []TrashItem{}, nil
	}
	if err != nil {
		return nil, err
	}
	var items []TrashItem
	if err := json.Unmarshal(data, &items); err != nil {
		return []TrashItem{}, nil
	}
	return items, nil
}

func (m *Manager) writeManifest(trashDir string, items []TrashItem) error {
	manifestPath := filepath.Join(trashDir, ManifestFileName)
	data, err := json.MarshalIndent(items, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(manifestPath, data, 0644)
}

// MoveToTrash intercepts file deletion/overwrite and moves the file to .tandem-trash with timestamp metadata.
func (m *Manager) MoveToTrash(folderRoot, relPath string) (*TrashItem, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	srcPath := filepath.Join(folderRoot, relPath)
	fi, err := os.Stat(srcPath)
	if err != nil {
		return nil, fmt.Errorf("file does not exist: %w", err)
	}

	trashDir := m.getTrashDir(folderRoot)
	if err := os.MkdirAll(trashDir, 0700); err != nil {
		return nil, fmt.Errorf("failed to create trash directory: %w", err)
	}

	trashID := fmt.Sprintf("%d_%s", time.Now().UnixNano(), filepath.Base(relPath))
	destPath := filepath.Join(trashDir, trashID)

	// Move file
	if err := os.Rename(srcPath, destPath); err != nil {
		return nil, fmt.Errorf("failed moving file to trash: %w", err)
	}

	item := TrashItem{
		TrashID:      trashID,
		OriginalPath: filepath.ToSlash(relPath),
		DeletedAt:    time.Now(),
		SizeBytes:    fi.Size(),
	}

	items, _ := m.readManifest(trashDir)
	items = append(items, item)
	_ = m.writeManifest(trashDir, items)

	return &item, nil
}

// ListTrash returns all recoverable files currently in the folder's trash.
func (m *Manager) ListTrash(folderRoot string) ([]TrashItem, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	trashDir := m.getTrashDir(folderRoot)
	return m.readManifest(trashDir)
}

// RestoreFromTrash recovers a deleted file back to its original location.
func (m *Manager) RestoreFromTrash(folderRoot, trashID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	trashDir := m.getTrashDir(folderRoot)
	items, err := m.readManifest(trashDir)
	if err != nil {
		return err
	}

	var targetItem *TrashItem
	var remaining []TrashItem
	for _, it := range items {
		if it.TrashID == trashID {
			targetItem = &it
		} else {
			remaining = append(remaining, it)
		}
	}

	if targetItem == nil {
		return fmt.Errorf("trash item %q not found", trashID)
	}

	src := filepath.Join(trashDir, targetItem.TrashID)
	dest := filepath.Join(folderRoot, targetItem.OriginalPath)

	if err := os.MkdirAll(filepath.Dir(dest), 0755); err != nil {
		return fmt.Errorf("failed creating restore parent directory: %w", err)
	}

	if err := os.Rename(src, dest); err != nil {
		return fmt.Errorf("failed restoring file: %w", err)
	}

	_ = m.writeManifest(trashDir, remaining)
	return nil
}

// PurgeExpired deletes items whose age exceeds the configured retention duration.
func (m *Manager) PurgeExpired(folderRoot string) (int, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	trashDir := m.getTrashDir(folderRoot)
	items, err := m.readManifest(trashDir)
	if err != nil {
		return 0, err
	}

	now := time.Now()
	var kept []TrashItem
	purgedCount := 0

	for _, it := range items {
		if now.Sub(it.DeletedAt) > m.retentionDur {
			filePath := filepath.Join(trashDir, it.TrashID)
			_ = os.Remove(filePath)
			purgedCount++
		} else {
			kept = append(kept, it)
		}
	}

	if purgedCount > 0 {
		_ = m.writeManifest(trashDir, kept)
	}

	return purgedCount, nil
}
