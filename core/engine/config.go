package engine

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// EngineConfig holds configuration for the supervised Syncthing engine and daemon.
type EngineConfig struct {
	ConfigDir       string `json:"-"`
	DataDir         string `json:"-"`
	ReceiveDir      string `json:"receiveDir,omitempty"`
	BindAddr        string `json:"bind,omitempty"`
	GUIAddress      string `json:"engineGui,omitempty"`
	APIKey          string `json:"-"`
	EngineAPIKey    string `json:"-"`
	DeviceName      string `json:"deviceName,omitempty"`
	SyncPort        int    `json:"syncPort,omitempty"`
	DiscoveryPort   int    `json:"discoveryPort,omitempty"`
	LocalDiscovery  bool   `json:"localDiscovery,omitempty"`
	GlobalDiscovery bool   `json:"globalDiscovery,omitempty"`
	RelaysEnabled   bool   `json:"relays,omitempty"`
	NATEnabled      bool   `json:"nat,omitempty"`
	NumConnections  int    `json:"numConnections,omitempty"`
	MinDiskFreeMB   int    `json:"minDiskFreeMb,omitempty"`
}

// DefaultConfig loads or initializes persistent configuration and API keys in baseDir.
func DefaultConfig(baseDir string) (*EngineConfig, error) {
	if baseDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			baseDir = "."
		} else {
			baseDir = filepath.Join(home, ".config", "tandem")
		}
	}

	if err := os.MkdirAll(baseDir, 0700); err != nil {
		return nil, fmt.Errorf("failed to create base dir: %w", err)
	}

	configDir := filepath.Join(baseDir, "syncthing")
	dataDir := filepath.Join(baseDir, "data")
	receiveDir := filepath.Join(baseDir, "received")

	apiKey, err := loadOrCreateKey(filepath.Join(baseDir, "api.key"))
	if err != nil {
		return nil, fmt.Errorf("failed loading api.key: %w", err)
	}
	engineKey, err := loadOrCreateKey(filepath.Join(baseDir, "engine.key"))
	if err != nil {
		return nil, fmt.Errorf("failed loading engine.key: %w", err)
	}

	hostname, _ := os.Hostname()
	if hostname == "" {
		hostname = "Tandem Device"
	}

	cfg := &EngineConfig{
		ConfigDir:       configDir,
		DataDir:         dataDir,
		ReceiveDir:      receiveDir,
		BindAddr:        "127.0.0.1:8385",
		GUIAddress:      "127.0.0.1:8384",
		APIKey:          apiKey,
		EngineAPIKey:    engineKey,
		DeviceName:      hostname,
		SyncPort:        22000,
		DiscoveryPort:   21027,
		LocalDiscovery:  true,
		GlobalDiscovery: true,
		RelaysEnabled:   true,
		NATEnabled:      true,
		NumConnections:  4,
		MinDiskFreeMB:   0,
	}

	// Optional per-instance overrides from <baseDir>/config.json
	cfgFile := filepath.Join(baseDir, "config.json")
	if raw, err := os.ReadFile(cfgFile); err == nil && len(strings.TrimSpace(string(raw))) > 0 {
		var disk map[string]json.RawMessage
		if err := json.Unmarshal(raw, &disk); err != nil {
			return nil, fmt.Errorf("failed parsing %s: %w", cfgFile, err)
		}
		if err := json.Unmarshal(raw, cfg); err != nil {
			return nil, fmt.Errorf("failed decoding %s: %w", cfgFile, err)
		}
		cfg.ConfigDir = configDir
		cfg.DataDir = dataDir
		cfg.APIKey = apiKey
		cfg.EngineAPIKey = engineKey
		if cfg.ReceiveDir == "" {
			cfg.ReceiveDir = receiveDir
		}
		if cfg.BindAddr == "" {
			cfg.BindAddr = "127.0.0.1:8385"
		}
		if cfg.GUIAddress == "" {
			cfg.GUIAddress = "127.0.0.1:8384"
		}
		if cfg.SyncPort <= 0 {
			cfg.SyncPort = 22000
		}
		if cfg.DiscoveryPort <= 0 {
			cfg.DiscoveryPort = 21027
		}
	}

	return cfg, nil
}

func loadOrCreateKey(path string) (string, error) {
	if raw, err := os.ReadFile(path); err == nil {
		key := strings.TrimSpace(string(raw))
		if len(key) >= 16 {
			_ = os.Chmod(path, 0600)
			return key, nil
		}
	}

	keyBytes := make([]byte, 16)
	if _, err := rand.Read(keyBytes); err != nil {
		return "", fmt.Errorf("failed generating random key: %w", err)
	}
	key := hex.EncodeToString(keyBytes)
	if err := os.WriteFile(path, []byte(key), 0600); err != nil {
		return "", fmt.Errorf("failed writing key %s: %w", path, err)
	}
	return key, nil
}

// EnsureDirectories creates required configuration and state directories with secure permissions.
func (c *EngineConfig) EnsureDirectories() error {
	if err := os.MkdirAll(c.ConfigDir, 0700); err != nil {
		return fmt.Errorf("failed to create config dir: %w", err)
	}
	if err := os.MkdirAll(c.DataDir, 0700); err != nil {
		return fmt.Errorf("failed to create data dir: %w", err)
	}
	if c.ReceiveDir != "" {
		if err := os.MkdirAll(c.ReceiveDir, 0755); err != nil {
			return fmt.Errorf("failed to create receive dir: %w", err)
		}
	}
	return nil
}
