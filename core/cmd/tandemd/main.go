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
	"tandem/core/engine"
	"tandem/core/linkmanager"
	"tandem/core/pal"
	"tandem/core/pal_darwin"
	"tandem/core/pal_linux"
	"tandem/core/pal_windows"
	"tandem/core/pairing"
)

// Build metadata injected via -ldflags at release build time.
var (
	version   = "0.2.2"
	commit    = "dev"
	buildDate = "unknown"
	channel   = "stable"
)

func main() {
	configDirFlag := flag.String("config", "", "Path to Tandem configuration directory")
	apiBindFlag := flag.String("bind", "127.0.0.1:8385", "Local API loopback bind address")
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
	var autostart pal.Autostart
	var lifecycle pal.Lifecycle

	switch runtime.GOOS {
	case "windows":
		w := pal_windows.NewWindowsAdapter()
		netAdapter = w
		fwAdapter = w
		autostart = w
		lifecycle = w
	case "darwin":
		d := pal_darwin.NewDarwinAdapter()
		netAdapter = d
		fwAdapter = d
		autostart = d
		lifecycle = d
	case "linux":
		l := pal_linux.NewLinuxAdapter()
		netAdapter = l
		fwAdapter = l
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
		_ = os.MkdirAll(baseDir, 0700)
	}

	engineCfg, err := engine.DefaultConfig(baseDir)
	if err != nil {
		log.Fatalf("failed to create engine config: %v", err)
	}

	// Write API key to disk with strict permissions (0600) for UI client access
	apiKeyPath := filepath.Join(baseDir, "api.key")
	_ = os.MkdirAll(baseDir, 0700)
	if err := os.WriteFile(apiKeyPath, []byte(engineCfg.APIKey), 0600); err != nil {
		log.Printf("warning: could not write api.key file: %v", err)
	}

	// 3. Initialize components
	hostname, _ := os.Hostname()
	if hostname == "" {
		hostname = "Tandem Device"
	}

	linkMgr := linkmanager.NewManager()
	pairingSvc := pairing.NewService("TANDEM-LOCAL-ID", hostname)

	apiServer := api.NewServer(api.ServerConfig{
		BindAddr:   *apiBindFlag,
		APIKey:     engineCfg.APIKey,
		Version:    version,
		DeviceID:   "TANDEM-LOCAL-ID",
		DeviceName: hostname,
	}, netAdapter, fwAdapter, linkMgr, pairingSvc)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 4. Power lifecycle management: hold system awake during execution
	releaseAwake := lifecycle.HoldAwake("Tandem daemon active synchronization")
	defer releaseAwake()

	// 5. Handle shutdown signals
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	go func() {
		sig := <-sigCh
		log.Printf("received signal %v, shutting down...", sig)
		cancel()
		_ = apiServer.Stop()
	}()

	log.Printf("starting tandemd %s on %s...", version, *apiBindFlag)
	log.Printf("Tandem API Key written to: %s", apiKeyPath)

	if err := apiServer.Start(ctx); err != nil && err != context.Canceled {
		log.Fatalf("server stopped with error: %v", err)
	}
}
