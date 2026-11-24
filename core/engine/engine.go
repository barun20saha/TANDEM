package engine

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"
)

// EngineState represents the lifecycle status of the sync engine.
type EngineState string

const (
	EngineStateStopped  EngineState = "stopped"
	EngineStateStarting EngineState = "starting"
	EngineStateRunning  EngineState = "running"
	EngineStateError    EngineState = "error"
)

// SyncthingEngine manages the lifecycle and REST communication with the headless sync engine.
type SyncthingEngine struct {
	config     *EngineConfig
	binaryPath string
	mu         sync.RWMutex
	state      EngineState
	cmd        *exec.Cmd
	client     *http.Client
	myDeviceID string
}

func NewSyncthingEngine(cfg *EngineConfig, binaryPath string) *SyncthingEngine {
	if binaryPath == "" {
		// Default search paths for syncthing binary
		paths := []string{
			"/tmp/tools/syncthing",
			"/usr/local/bin/syncthing",
			"/usr/bin/syncthing",
		}
		for _, p := range paths {
			if _, err := os.Stat(p); err == nil {
				binaryPath = p
				break
			}
		}
		if binaryPath == "" {
			binaryPath = "syncthing"
		}
	}

	return &SyncthingEngine{
		config:     cfg,
		binaryPath: binaryPath,
		state:      EngineStateStopped,
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

// Start launches the headless engine with strict loopback and browser-disabled parameters.
func (e *SyncthingEngine) Start(ctx context.Context) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if e.state == EngineStateRunning {
		return nil
	}
	e.state = EngineStateStarting

	if err := e.config.EnsureDirectories(); err != nil {
		e.state = EngineStateError
		return err
	}

	args := []string{
		fmt.Sprintf("-home=%s", e.config.ConfigDir),
		fmt.Sprintf("-gui-address=%s", e.config.GUIAddress),
		fmt.Sprintf("-gui-apikey=%s", e.config.APIKey),
		"-no-browser",
		"-no-restart",
		"-no-default-folder",
		"-logflags=0",
	}

	cmd := exec.CommandContext(ctx, e.binaryPath, args...)
	cmd.Dir = e.config.ConfigDir

	// Redirect stdout/stderr to log file in config dir
	logFile, err := os.OpenFile(filepath.Join(e.config.ConfigDir, "syncthing.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0600)
	if err == nil {
		cmd.Stdout = logFile
		cmd.Stderr = logFile
	}

	if err := cmd.Start(); err != nil {
		e.state = EngineStateError
		return fmt.Errorf("failed to start syncthing: %w", err)
	}
	e.cmd = cmd
	e.state = EngineStateRunning

	// Start supervisor goroutine
	go func() {
		_ = cmd.Wait()
		e.mu.Lock()
		e.state = EngineStateStopped
		e.mu.Unlock()
	}()

	return nil
}

// Stop terminates the engine cleanly.
func (e *SyncthingEngine) Stop() error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if e.cmd != nil && e.cmd.Process != nil {
		_ = e.cmd.Process.Kill()
	}
	e.state = EngineStateStopped
	return nil
}

// State returns the current engine state.
func (e *SyncthingEngine) State() EngineState {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.state
}

// Ping checks if the engine REST API is responsive.
func (e *SyncthingEngine) Ping(ctx context.Context) bool {
	url := fmt.Sprintf("http://%s/rest/system/ping", e.config.GUIAddress)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return false
	}
	req.Header.Set("X-API-Key", e.config.APIKey)

	resp, err := e.client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

// GetSystemStatus queries the engine for its Device ID and version.
func (e *SyncthingEngine) GetSystemStatus(ctx context.Context) (map[string]interface{}, error) {
	url := fmt.Sprintf("http://%s/rest/system/status", e.config.GUIAddress)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-API-Key", e.config.APIKey)

	resp, err := e.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	if id, ok := result["myID"].(string); ok {
		e.mu.Lock()
		e.myDeviceID = id
		e.mu.Unlock()
	}
	return result, nil
}

// DeviceID returns the cached or discovered local Device ID.
func (e *SyncthingEngine) DeviceID() string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.myDeviceID
}
