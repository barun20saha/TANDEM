package folders

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"tandem/core/engine/compat"
	"tandem/core/trash"
)

type FolderType string

const (
	TypeSendReceive FolderType = "sendreceive"
	TypeSendOnly    FolderType = "sendonly"
	TypeReceiveOnly FolderType = "receiveonly"
)

type FolderState string

const (
	StateIdle      FolderState = "idle"
	StateSyncing   FolderState = "syncing"
	StatePaused    FolderState = "paused"
	StateConflicts FolderState = "conflicts"
	StateError     FolderState = "error"
)

// Folder represents a configured synchronized folder.
type Folder struct {
	ID            string      `json:"id"`
	Label         string      `json:"label"`
	Path          string      `json:"path"`
	Type          FolderType  `json:"type"`
	State         FolderState `json:"state"`
	Paused        bool        `json:"paused"`
	SharedDevices []string    `json:"sharedDevices"`
	TotalBytes    int64       `json:"totalBytes"`
	TotalFiles    int         `json:"totalFiles"`
	CreatedAt     time.Time   `json:"createdAt"`
}

// Manager controls folder lifecycle, storage policies, and safe deletion.
type Manager struct {
	mu       sync.RWMutex
	folders  map[string]*Folder
	trashMgr *trash.Manager
}

func NewManager(tm *trash.Manager) *Manager {
	return &Manager{
		folders:  make(map[string]*Folder),
		trashMgr: tm,
	}
}

// AddFolder registers a directory for synchronization.
func (m *Manager) AddFolder(id, label, path string, fType FolderType, devices []string) (*Folder, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.folders[id]; exists {
		return nil, fmt.Errorf("folder with id %q already exists", id)
	}

	if fType == "" {
		fType = TypeSendReceive
	}

	f := &Folder{
		ID:            id,
		Label:         label,
		Path:          filepath.Clean(path),
		Type:          fType,
		State:         StateIdle,
		Paused:        false,
		SharedDevices: devices,
		CreatedAt:     time.Now(),
	}

	m.folders[id] = f
	return f, nil
}

// UpdateFolder modifies settings on an existing folder.
func (m *Manager) UpdateFolder(id string, paused *bool, fType *FolderType, devices []string) (*Folder, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	f, exists := m.folders[id]
	if !exists {
		return nil, fmt.Errorf("folder %s not found", id)
	}

	if paused != nil {
		f.Paused = *paused
		if *paused {
			f.State = StatePaused
		} else {
			f.State = StateIdle
		}
	}
	if fType != nil {
		f.Type = *fType
	}
	if devices != nil {
		f.SharedDevices = devices
	}

	return f, nil
}

// ScanConflicts scans a folder tree for case collisions, reserved names, and invalid characters.
func (m *Manager) ScanConflicts(id string) ([]string, error) {
	m.mu.RLock()
	f, exists := m.folders[id]
	m.mu.RUnlock()

	if !exists {
		return nil, fmt.Errorf("folder %s not found", id)
	}

	var allNames []string
	var conflictMsgs []string

	err := filepath.Walk(f.Path, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if compat.ShouldIgnoreFile(path) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		rel, _ := filepath.Rel(f.Path, path)
		if rel == "." {
			return nil
		}

		base := filepath.Base(path)
		allNames = append(allNames, rel)

		// Check Windows reserved names
		if cType, msg := compat.CheckNameCompatibility(base, "windows"); cType != compat.ConflictNone {
			conflictMsgs = append(conflictMsgs, fmt.Sprintf("%s: %s", rel, msg))
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	// Detect case collisions
	collisions := compat.DetectCaseCollisions(allNames)
	for key, collList := range collisions {
		conflictMsgs = append(conflictMsgs, fmt.Sprintf("Case collision (%s): %v", key, collList))
	}

	return conflictMsgs, nil
}

// DeleteFileSafe moves a file to the folder's .tandem-trash directory (never silently deletes, Rule 6).
func (m *Manager) DeleteFileSafe(folderID, relPath string) (*trash.TrashItem, error) {
	m.mu.RLock()
	f, exists := m.folders[folderID]
	m.mu.RUnlock()

	if !exists {
		return nil, fmt.Errorf("folder %s not found", folderID)
	}

	return m.trashMgr.MoveToTrash(f.Path, relPath)
}
