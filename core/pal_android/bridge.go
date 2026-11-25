package pal_android

import (
	"context"
	"log"
	"os"
	"path/filepath"
	"sync"

	"tandem/core/api"
	"tandem/core/discovery"
	"tandem/core/engine"
	"tandem/core/linkmanager"
	"tandem/core/pairing"
	"tandem/core/send"
)

var (
	mu         sync.Mutex
	cancelFunc context.CancelFunc
	apiSrv     *api.Server
	syncEng    *engine.SyncthingEngine
	lastErr    string
)

// StartEngine starts the real in-process Tandem API, discovery, and Syncthing engine supervisor.
// syncthingPath should point to <nativeLibraryDir>/libsyncthing.so on Android.
func StartEngine(configPath string, syncthingPath string) int {
	mu.Lock()
	defer mu.Unlock()

	if cancelFunc != nil {
		return 0
	}
	lastErr = ""
	if configPath == "" {
		lastErr = "empty configPath"
		return -1
	}
	if err := os.MkdirAll(configPath, 0700); err != nil {
		lastErr = err.Error()
		return -1
	}

	cfg, err := engine.DefaultConfig(configPath)
	if err != nil {
		lastErr = err.Error()
		return -1
	}

	ctx, cancel := context.WithCancel(context.Background())
	if syncthingPath == "" {
		syncthingPath = filepath.Join(configPath, "libsyncthing.so")
	}

	eng := engine.NewSyncthingEngine(cfg, syncthingPath)
	if err := eng.Start(ctx); err != nil {
		cancel()
		lastErr = err.Error()
		log.Printf("[Android PAL] failed starting sync engine: %v", err)
		return -2
	}

	localID := eng.DeviceID()
	androidPal := NewAndroidAdapter()
	discSvc := discovery.NewService(discovery.Config{
		DeviceID:      localID,
		DeviceName:    cfg.DeviceName,
		Port:          cfg.SyncPort,
		DiscoveryPort: cfg.DiscoveryPort,
	})
	_ = discSvc.Start(ctx, androidPal, nil)

	linkMgr := linkmanager.NewManager()
	pairingSvc := pairing.NewService(localID, cfg.DeviceName)
	sendMgr := send.NewManager(configPath)
	srv := api.NewServer(api.ServerConfig{
		BindAddr:      "127.0.0.1:8385",
		APIKey:        cfg.APIKey,
		DeviceID:      localID,
		DeviceName:    cfg.DeviceName,
		SyncPort:      cfg.SyncPort,
		DiscoveryPort: cfg.DiscoveryPort,
		ReceiveDir:    cfg.ReceiveDir,
	}, androidPal, androidPal, linkMgr, pairingSvc)
	srv.AttachRuntime(eng, discSvc, androidPal, sendMgr)

	go func() {
		if err := srv.Start(ctx); err != nil && ctx.Err() == nil {
			log.Printf("[Android PAL] api server stopped: %v", err)
		}
	}()

	cancelFunc = cancel
	apiSrv = srv
	syncEng = eng
	return 0
}

// StopEngine gracefully stops the API server and sync engine.
func StopEngine() int {
	mu.Lock()
	defer mu.Unlock()

	if cancelFunc != nil {
		cancelFunc()
		cancelFunc = nil
	}
	if apiSrv != nil {
		_ = apiSrv.Stop()
		apiSrv = nil
	}
	if syncEng != nil {
		_ = syncEng.Stop()
		syncEng = nil
	}
	return 0
}

// IsEngineActive returns 1 if the supervised sync engine is running, else 0.
func IsEngineActive() int {
	mu.Lock()
	defer mu.Unlock()

	if syncEng != nil && syncEng.State() == engine.EngineStateRunning {
		return 1
	}
	return 0
}

// LastError returns the last engine startup error message if any.
func LastError() string {
	mu.Lock()
	defer mu.Unlock()
	return lastErr
}
