package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"

	"tandem/core/api"
	"tandem/core/discovery"
	"tandem/core/engine"
	"tandem/core/linkmanager"
	"tandem/core/pal"
	"tandem/core/pal_darwin"
	"tandem/core/pal_linux"
	"tandem/core/pal_windows"
	"tandem/core/pairing"
	"tandem/core/send"
)

// Build metadata injected via -ldflags at release build time.
var (
	version   = "0.2.3"
	commit    = "dev"
	buildDate = "unknown"
	channel   = "stable"
)

func main() {
	configDirFlag := flag.String("config", "", "Path to Tandem configuration directory")
	apiBindFlag := flag.String("bind", "127.0.0.1:8385", "Local API loopback bind address")
	syncPortFlag := flag.Int("sync-port", 22000, "BEP TCP/QUIC sync listen port")
	discoveryPortFlag := flag.Int("discovery-port", 21027, "UDP local discovery port")
	engineGUIFlag := flag.String("engine-gui", "127.0.0.1:8384", "Internal Syncthing REST loopback address")
	syncthingBinFlag := flag.String("syncthing", "", "Path to pinned syncthing binary")
	deviceNameFlag := flag.String("device-name", "", "Display name for this device")
	receiveDirFlag := flag.String("receive-dir", "", "Directory for incoming one-off Send files")
	globalDiscFlag := flag.Bool("global-discovery", true, "Enable global discovery")
	relaysFlag := flag.Bool("relays", true, "Enable encrypted relay fallback")
	natFlag := flag.Bool("nat", true, "Enable UPnP/NAT-PMP port mapping")
	minDiskFreeMBFlag := flag.Int("min-disk-free-mb", 0, "Minimum free disk space in MB (0 = 1%% default)")
	autostartFlag := flag.Bool("autostart", false, "Enable system autostart on login and exit")
	versionFlag := flag.Bool("version", false, "Print version and exit")
	versionJSONFlag := flag.Bool("version-json", false, "Print structured build metadata as JSON and exit")
	flag.Parse()

	if *versionJSONFlag {
		payload := map[string]string{
			"version":   version,
			"commit":    commit,
			"buildDate": buildDate,
			"channel":   channel,
			"os":        runtime.GOOS,
			"arch":      runtime.GOARCH,
		}
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(payload)
		return
	}

	if *versionFlag {
		fmt.Printf("tandemd %s (%s/%s, channel=%s, commit=%s, built=%s)\n",
			version, runtime.GOOS, runtime.GOARCH, channel, commit, buildDate)
		return
	}

	// 1. Initialize OS Platform Abstraction Layer
	var netAdapter pal.Network
	var fwAdapter pal.Firewall
	var storageAdapter pal.Storage
	var autostart pal.Autostart
	var lifecycle pal.Lifecycle

	switch runtime.GOOS {
	case "windows":
		w := pal_windows.NewWindowsAdapter()
		netAdapter = w
		fwAdapter = w
		storageAdapter = w
		autostart = w
		lifecycle = w
	case "darwin":
		d := pal_darwin.NewDarwinAdapter()
		netAdapter = d
		fwAdapter = d
		storageAdapter = d
		autostart = d
		lifecycle = d
	case "linux":
		l := pal_linux.NewLinuxAdapter()
		netAdapter = l
		fwAdapter = l
		storageAdapter = l
		autostart = l
		lifecycle = l
	default:
		log.Fatalf("unsupported operating system: %s", runtime.GOOS)
	}

	if *autostartFlag {
		if err := autostart.Enable(); err != nil {
			log.Fatalf("failed to enable autostart: %v", err)
		}
		fmt.Println("Autostart enabled successfully.")
		return
	}

	// 2. Resolve base directory
	baseDir := *configDirFlag
	if baseDir == "" {
		home, err := os.UserHomeDir()
		if err == nil {
			baseDir = filepath.Join(home, ".config", "tandem")
		}
		if err := os.MkdirAll(baseDir, 0700); err != nil {
			baseDir = filepath.Join(".", ".tandem")
			_ = os.MkdirAll(baseDir, 0700)
		}
	} else {
		if err := os.MkdirAll(baseDir, 0700); err != nil {
			log.Fatalf("failed to create config dir %s: %v", baseDir, err)
		}
	}

	engineCfg, err := engine.DefaultConfig(baseDir)
	if err != nil {
		log.Fatalf("failed to create engine config: %v", err)
	}
	setFlags := make(map[string]bool)
	flag.Visit(func(f *flag.Flag) {
		setFlags[f.Name] = true
	})
	apiBind := engineCfg.BindAddr
	if apiBind == "" {
		apiBind = *apiBindFlag
	}
	if setFlags["bind"] {
		apiBind = *apiBindFlag
	}
	if setFlags["engine-gui"] {
		engineCfg.GUIAddress = *engineGUIFlag
	}
	if setFlags["sync-port"] {
		engineCfg.SyncPort = *syncPortFlag
	}
	if setFlags["discovery-port"] {
		engineCfg.DiscoveryPort = *discoveryPortFlag
	}
	if setFlags["global-discovery"] {
		engineCfg.GlobalDiscovery = *globalDiscFlag
	}
	if setFlags["relays"] {
		engineCfg.RelaysEnabled = *relaysFlag
	}
	if setFlags["nat"] {
		engineCfg.NATEnabled = *natFlag
	}
	if setFlags["min-disk-free-mb"] {
		engineCfg.MinDiskFreeMB = *minDiskFreeMBFlag
	}
	if setFlags["device-name"] && *deviceNameFlag != "" {
		engineCfg.DeviceName = *deviceNameFlag
	}
	if setFlags["receive-dir"] && *receiveDirFlag != "" {
		engineCfg.ReceiveDir = *receiveDirFlag
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 3. Start supervised Syncthing engine (generates/preserves TLS cert & Device ID)
	syncEngine := engine.NewSyncthingEngine(engineCfg, *syncthingBinFlag)
	if err := syncEngine.Start(ctx); err != nil {
		log.Fatalf("failed starting sync engine: %v", err)
	}
	defer func() {
		_ = syncEngine.Stop()
	}()

	localID := syncEngine.DeviceID()
	if localID == "" {
		log.Fatalf("sync engine started without a local Device ID")
	}

	// 4. Start local UDP discovery service on all active interfaces
	discSvc := discovery.NewService(discovery.Config{
		DeviceID:      localID,
		DeviceName:    engineCfg.DeviceName,
		Port:          engineCfg.SyncPort,
		DiscoveryPort: engineCfg.DiscoveryPort,
	})

	linkMgr := linkmanager.NewManager()
	pairingSvc := pairing.NewService(localID, engineCfg.DeviceName)
	sendMgr := send.NewManager(baseDir)

	apiServer := api.NewServer(api.ServerConfig{
		BindAddr:      apiBind,
		APIKey:        engineCfg.APIKey,
		Version:       version,
		DeviceID:      localID,
		DeviceName:    engineCfg.DeviceName,
		SyncPort:      engineCfg.SyncPort,
		DiscoveryPort: engineCfg.DiscoveryPort,
		ReceiveDir:    engineCfg.ReceiveDir,
	}, netAdapter, fwAdapter, linkMgr, pairingSvc)
	apiServer.AttachRuntime(syncEngine, discSvc, storageAdapter, sendMgr)

	if err := discSvc.Start(ctx, netAdapter, func(ann *discovery.Announcement) {
		// If already paired in Syncthing, update its discovered LAN address if currently dynamic
		if devs, err := syncEngine.GetConfigDevices(ctx); err == nil {
			for _, dev := range devs {
				if dev.DeviceID == ann.DeviceID && len(ann.Addresses) > 0 {
					hasAddr := false
					for _, a := range dev.Addresses {
						if a == ann.Addresses[0] {
							hasAddr = true
							break
						}
					}
					if !hasAddr {
						dev.Addresses = append(ann.Addresses, "dynamic")
						_ = syncEngine.UpsertDevice(ctx, dev)
					}
					break
				}
			}
		}
	}); err != nil {
		log.Printf("warning: discovery service failed to bind port %d: %v", engineCfg.DiscoveryPort, err)
	}

	// 5. Power lifecycle management
	releaseAwake := lifecycle.HoldAwake("Tandem daemon active synchronization")
	defer releaseAwake()

	// 6. Handle shutdown signals cleanly
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	go func() {
		sig := <-sigCh
		log.Printf("received signal %v, shutting down...", sig)
		_ = syncEngine.Stop()
		cancel()
		_ = apiServer.Stop()
	}()

	log.Printf("starting tandemd %s (deviceId=%s) API=%s sync=%d discovery=%d",
		version, localID, apiBind, engineCfg.SyncPort, engineCfg.DiscoveryPort)

	if err := apiServer.Start(ctx); err != nil && err != context.Canceled && err.Error() != "http: Server closed" {
		log.Fatalf("server stopped with error: %v", err)
	}
	_ = syncEngine.Stop()
}
