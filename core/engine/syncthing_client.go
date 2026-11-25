package engine

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

type DeviceConfig struct {
	DeviceID          string   `json:"deviceID"`
	Name              string   `json:"name"`
	Addresses         []string `json:"addresses"`
	Compression       string   `json:"compression,omitempty"`
	AutoAcceptFolders bool     `json:"autoAcceptFolders"`
	Paused            bool     `json:"paused"`
	NumConnections    int      `json:"numConnections,omitempty"`
}

type FolderDevice struct {
	DeviceID string `json:"deviceID"`
}

type VersioningConfig struct {
	Type             string            `json:"type"`
	Params           map[string]string `json:"params,omitempty"`
	FSPath           string            `json:"fsPath,omitempty"`
	FSType           string            `json:"fsType,omitempty"`
	CleanupIntervalS int               `json:"cleanupIntervalS,omitempty"`
}

type MinDiskFreeConfig struct {
	Value float64 `json:"value"`
	Unit  string  `json:"unit"`
}

type FolderConfig struct {
	ID               string            `json:"id"`
	Label            string            `json:"label"`
	Path             string            `json:"path"`
	Type             string            `json:"type"` // sendreceive, sendonly, receiveonly
	Paused           bool              `json:"paused"`
	Devices          []FolderDevice    `json:"devices"`
	FSWatcherEnabled bool              `json:"fsWatcherEnabled"`
	FSWatcherDelayS  int               `json:"fsWatcherDelayS"`
	RescanIntervalS  int               `json:"rescanIntervalS"`
	Versioning       VersioningConfig  `json:"versioning"`
	MinDiskFree      MinDiskFreeConfig `json:"minDiskFree"`
}

type ConnectionInfo struct {
	At            string `json:"at"`
	InBytesTotal  int64  `json:"inBytesTotal"`
	OutBytesTotal int64  `json:"outBytesTotal"`
	StartedAt     string `json:"startedAt"`
	Connected     bool   `json:"connected"`
	Paused        bool   `json:"paused"`
	Address       string `json:"address"`
	ClientVersion string `json:"clientVersion"`
	Type          string `json:"type"`
	IsLocal       bool   `json:"isLocal"`
}

type ConnectionsResponse struct {
	Connections map[string]ConnectionInfo `json:"connections"`
	Total       ConnectionInfo            `json:"total"`
}

type FolderStatus struct {
	Errors         int    `json:"errors"`
	PullErrors     int    `json:"pullErrors"`
	Invalid        string `json:"invalid"`
	Error          string `json:"error"`
	GlobalFiles    int    `json:"globalFiles"`
	GlobalBytes     int64  `json:"globalBytes"`
	LocalFiles      int    `json:"localFiles"`
	LocalBytes      int64  `json:"localBytes"`
	NeedFiles       int    `json:"needFiles"`
	NeedBytes       int64  `json:"needBytes"`
	InSyncBytes     int64  `json:"inSyncBytes"`
	State           string `json:"state"`
	StateChanged    string `json:"stateChanged"`
	ReceiveOnlyTot  int    `json:"receiveOnlyTotalItems"`
}

type FolderErrorItem struct {
	Path  string `json:"path"`
	Error string `json:"error"`
}

type FolderErrorsResponse struct {
	Folder string            `json:"folder"`
	Errors []FolderErrorItem `json:"errors"`
	Page   int               `json:"page"`
}

type CompletionResponse struct {
	Completion  float64 `json:"completion"`
	GlobalBytes int64   `json:"globalBytes"`
	NeedBytes   int64   `json:"needBytes"`
	NeedItems   int     `json:"needItems"`
}

type PendingFolderOfferedBy struct {
	Time             string `json:"time"`
	Label            string `json:"label"`
	ReceiveEncrypted bool   `json:"receiveEncrypted"`
}

type PendingFolderEntry struct {
	OfferedBy map[string]PendingFolderOfferedBy `json:"offeredBy"`
}

type SyncthingEvent struct {
	ID   int64                  `json:"id"`
	Type string                 `json:"type"`
	Time string                 `json:"time"`
	Data map[string]interface{} `json:"data"`
}

func (e *SyncthingEngine) apiKey() string {
	if e.config.EngineAPIKey != "" {
		return e.config.EngineAPIKey
	}
	return e.config.APIKey
}

func (e *SyncthingEngine) doReq(ctx context.Context, method, path string, body any, out any) (int, error) {
	var reader io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			return 0, err
		}
		reader = bytes.NewReader(raw)
	}
	req, err := http.NewRequestWithContext(ctx, method, "http://"+e.config.GUIAddress+path, reader)
	if err != nil {
		return 0, err
	}
	req.Header.Set("X-API-Key", e.apiKey())
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := e.client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp.StatusCode, err
	}
	if resp.StatusCode >= 400 {
		return resp.StatusCode, fmt.Errorf("syncthing API %s %s failed (%d): %s", method, path, resp.StatusCode, strings.TrimSpace(string(respBytes)))
	}
	if out != nil && len(bytes.TrimSpace(respBytes)) > 0 {
		if err := json.Unmarshal(respBytes, out); err != nil {
			return resp.StatusCode, err
		}
	}
	return resp.StatusCode, nil
}

func (e *SyncthingEngine) postJSON(ctx context.Context, path string, body any, out any) error {
	_, err := e.doReq(ctx, http.MethodPost, path, body, out)
	return err
}

func (e *SyncthingEngine) Ping(ctx context.Context) bool {
	code, err := e.doReq(ctx, http.MethodGet, "/rest/system/ping", nil, nil)
	return err == nil && code == http.StatusOK
}

func (e *SyncthingEngine) GetSystemStatus(ctx context.Context) (map[string]interface{}, error) {
	var result map[string]interface{}
	if _, err := e.doReq(ctx, http.MethodGet, "/rest/system/status", nil, &result); err != nil {
		return nil, err
	}
	if id, ok := result["myID"].(string); ok && id != "" {
		e.mu.Lock()
		e.myDeviceID = id
		e.mu.Unlock()
	}
	return result, nil
}

func (e *SyncthingEngine) GetConnections(ctx context.Context) (*ConnectionsResponse, error) {
	var out ConnectionsResponse
	if _, err := e.doReq(ctx, http.MethodGet, "/rest/system/connections", nil, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (e *SyncthingEngine) GetConfigDevices(ctx context.Context) ([]DeviceConfig, error) {
	var out []DeviceConfig
	if _, err := e.doReq(ctx, http.MethodGet, "/rest/config/devices", nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func (e *SyncthingEngine) UpsertDevice(ctx context.Context, dev DeviceConfig) error {
	if len(dev.Addresses) == 0 {
		dev.Addresses = []string{"dynamic"}
	}
	if dev.Compression == "" {
		dev.Compression = "metadata"
	}
	if dev.NumConnections == 0 && e.config.NumConnections > 0 {
		dev.NumConnections = e.config.NumConnections
	}
	_, err := e.doReq(ctx, http.MethodPut, "/rest/config/devices/"+url.PathEscape(dev.DeviceID), dev, nil)
	return err
}

func (e *SyncthingEngine) DeleteDevice(ctx context.Context, deviceID string) error {
	_, err := e.doReq(ctx, http.MethodDelete, "/rest/config/devices/"+url.PathEscape(deviceID), nil, nil)
	return err
}

func (e *SyncthingEngine) GetConfigFolders(ctx context.Context) ([]FolderConfig, error) {
	var out []FolderConfig
	if _, err := e.doReq(ctx, http.MethodGet, "/rest/config/folders", nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func (e *SyncthingEngine) GetConfigFolder(ctx context.Context, folderID string) (*FolderConfig, error) {
	var out FolderConfig
	if _, err := e.doReq(ctx, http.MethodGet, "/rest/config/folders/"+url.PathEscape(folderID), nil, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

// EnsureFolderIgnore writes Tandem's cross-OS junk & trash ignore patterns to .stignore.
func EnsureFolderIgnore(folderPath string) error {
	ignorePath := filepath.Join(folderPath, ".stignore")
	if _, err := os.Stat(ignorePath); err == nil {
		return nil
	}
	content := strings.Join([]string{
		".tandem-trash",
		".tandem-tmp*",
		".DS_Store",
		"Thumbs.db",
		"desktop.ini",
		".Trash*",
		"~$*",
	}, "\n") + "\n"
	return os.WriteFile(ignorePath, []byte(content), 0644)
}

func (e *SyncthingEngine) UpsertFolder(ctx context.Context, f FolderConfig) error {
	if err := os.MkdirAll(f.Path, 0755); err != nil {
		return err
	}
	_ = EnsureFolderIgnore(f.Path)

	if f.Type == "" {
		f.Type = "sendreceive"
	}
	if !f.FSWatcherEnabled {
		f.FSWatcherEnabled = true
	}
	if f.FSWatcherDelayS <= 0 {
		f.FSWatcherDelayS = 1
	}
	if f.RescanIntervalS <= 0 {
		f.RescanIntervalS = 60
	}
	if f.Versioning.Type == "" {
		f.Versioning = VersioningConfig{
			Type:             "trashcan",
			FSPath:           filepath.Join(f.Path, ".tandem-trash"),
			FSType:           "basic",
			CleanupIntervalS: 3600,
			Params: map[string]string{
				"cleanoutDays": "30",
			},
		}
	}
	if f.MinDiskFree.Unit == "" {
		if e.config.MinDiskFreeMB > 0 {
			f.MinDiskFree = MinDiskFreeConfig{Value: float64(e.config.MinDiskFreeMB), Unit: "MB"}
		} else {
			f.MinDiskFree = MinDiskFreeConfig{Value: 1, Unit: "%"}
		}
	}

	// Ensure local device is always included in folder devices
	myID := e.DeviceID()
	hasSelf := false
	for _, d := range f.Devices {
		if d.DeviceID == myID {
			hasSelf = true
			break
		}
	}
	if !hasSelf && myID != "" {
		f.Devices = append([]FolderDevice{{DeviceID: myID}}, f.Devices...)
	}

	_, err := e.doReq(ctx, http.MethodPut, "/rest/config/folders/"+url.PathEscape(f.ID), f, nil)
	return err
}

func (e *SyncthingEngine) DeleteFolder(ctx context.Context, folderID string) error {
	_, err := e.doReq(ctx, http.MethodDelete, "/rest/config/folders/"+url.PathEscape(folderID), nil, nil)
	return err
}

func (e *SyncthingEngine) RescanFolder(ctx context.Context, folderID string) error {
	return e.postJSON(ctx, "/rest/db/scan?folder="+url.QueryEscape(folderID), nil, nil)
}

func (e *SyncthingEngine) GetFolderStatus(ctx context.Context, folderID string) (*FolderStatus, error) {
	var out FolderStatus
	if _, err := e.doReq(ctx, http.MethodGet, "/rest/db/status?folder="+url.QueryEscape(folderID), nil, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (e *SyncthingEngine) GetFolderErrors(ctx context.Context, folderID string) (*FolderErrorsResponse, error) {
	var out FolderErrorsResponse
	if _, err := e.doReq(ctx, http.MethodGet, "/rest/folder/errors?folder="+url.QueryEscape(folderID), nil, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (e *SyncthingEngine) GetCompletion(ctx context.Context, folderID, deviceID string) (*CompletionResponse, error) {
	var out CompletionResponse
	path := fmt.Sprintf("/rest/db/completion?folder=%s&device=%s", url.QueryEscape(folderID), url.QueryEscape(deviceID))
	if _, err := e.doReq(ctx, http.MethodGet, path, nil, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (e *SyncthingEngine) GetPendingFolders(ctx context.Context) (map[string]PendingFolderEntry, error) {
	var out map[string]PendingFolderEntry
	if _, err := e.doReq(ctx, http.MethodGet, "/rest/cluster/pending/folders", nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func (e *SyncthingEngine) PollEvents(ctx context.Context, since int64, timeoutSec int) ([]SyncthingEvent, error) {
	var out []SyncthingEvent
	path := fmt.Sprintf("/rest/events?since=%d&timeout=%d", since, timeoutSec)
	if _, err := e.doReq(ctx, http.MethodGet, path, nil, &out); err != nil {
		return nil, err
	}
	return out, nil
}
