package send

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"time"
)

type SessionState string

const (
	SessionStateQueued    SessionState = "queued"
	SessionStateSending   SessionState = "sending"
	SessionStateCompleted SessionState = "completed"
	SessionStateFailed    SessionState = "failed"
	SessionStateCancelled SessionState = "cancelled"
)

// Session represents an ephemeral, single-recipient transfer (DECISION D2).
type Session struct {
	SessionID       string       `json:"sessionId"`
	TargetDeviceID  string       `json:"targetDeviceId"`
	State           SessionState `json:"state"`
	FilesSent       int          `json:"filesSent"`
	TotalFiles      int          `json:"totalFiles"`
	BytesSent       int64        `json:"bytesSent"`
	TotalBytes      int64        `json:"totalBytes"`
	SpeedBytes      int64        `json:"speedBytesPerSec"`
	EphemeralFolder string       `json:"ephemeralFolder"`
	CreatedAt       time.Time    `json:"createdAt"`
}

// Manager controls the lifecycle of ephemeral Send folders.
type Manager struct {
	mu          sync.RWMutex
	baseDir     string
	sessions    map[string]*Session
}

func NewManager(baseDir string) *Manager {
	return &Manager{
		baseDir:  baseDir,
		sessions: make(map[string]*Session),
	}
}

// CreateSession stages files into a dedicated ephemeral folder for one-off transmission.
func (m *Manager) CreateSession(targetDeviceID string, filePaths []string) (*Session, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	sessionID := fmt.Sprintf("send_%d", time.Now().UnixNano())
	ephemeralDir := filepath.Join(m.baseDir, "ephemeral", sessionID)

	if err := os.MkdirAll(ephemeralDir, 0700); err != nil {
		return nil, fmt.Errorf("failed creating ephemeral directory: %w", err)
	}

	var totalBytes int64
	for _, src := range filePaths {
		fi, err := os.Stat(src)
		if err != nil {
			_ = os.RemoveAll(ephemeralDir)
			return nil, fmt.Errorf("source file error: %w", err)
		}
		totalBytes += fi.Size()

		dest := filepath.Join(ephemeralDir, filepath.Base(src))
		// Hardlink if possible for zero-copy, fallback to copy
		if err := os.Link(src, dest); err != nil {
			if err := copyFile(src, dest); err != nil {
				_ = os.RemoveAll(ephemeralDir)
				return nil, fmt.Errorf("failed staging file: %w", err)
			}
		}
	}

	sess := &Session{
		SessionID:       sessionID,
		TargetDeviceID:  targetDeviceID,
		State:           SessionStateSending,
		FilesSent:       0,
		TotalFiles:      len(filePaths),
		BytesSent:       0,
		TotalBytes:      totalBytes,
		SpeedBytes:      10 * 1024 * 1024, // Initial nominal 10 MB/s
		EphemeralFolder: ephemeralDir,
		CreatedAt:       time.Now(),
	}

	m.sessions[sessionID] = sess
	return sess, nil
}

// GetSession returns a snapshot of the session state.
func (m *Manager) GetSession(sessionID string) (*Session, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	sess, exists := m.sessions[sessionID]
	return sess, exists
}

// CompleteSession finishes transfer and cleans up ephemeral storage.
func (m *Manager) CompleteSession(sessionID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	sess, exists := m.sessions[sessionID]
	if !exists {
		return fmt.Errorf("session %s not found", sessionID)
	}

	sess.State = SessionStateCompleted
	sess.FilesSent = sess.TotalFiles
	sess.BytesSent = sess.TotalBytes

	// Unlink and remove ephemeral folder
	if err := os.RemoveAll(sess.EphemeralFolder); err != nil {
		return fmt.Errorf("cleanup failed: %w", err)
	}
	return nil
}

func copyFile(src, dest string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}
