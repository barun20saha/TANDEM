package engine

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
)

// EngineConfig holds configuration for the embedded Syncthing engine.
type EngineConfig struct {
	ConfigDir       string
	DataDir         string
	GUIAddress      string
	APIKey          string
	LocalDiscovery  bool
	GlobalDiscovery bool
	RelaysEnabled   bool
	NATEnabled      bool
	NumConnections  int
}

// DefaultConfig generates a secure default configuration conforming to Tandem specifications.
func DefaultConfig(baseDir string) (*EngineConfig, error) {
	if baseDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			baseDir = "."
		} else {
			baseDir = filepath.Join(home, ".config", "tandem")
		}
	}

	configDir := filepath.Join(baseDir, "syncthing")
	dataDir := filepath.Join(baseDir, "data")

	// Generate random 32-byte API key
	keyBytes := make([]byte, 16)
	if _, err := rand.Read(keyBytes); err != nil {
		return nil, fmt.Errorf("failed to generate random API key: %w", err)
	}
	apiKey := hex.EncodeToString(keyBytes)

	return &EngineConfig{
		ConfigDir:       configDir,
		DataDir:         dataDir,
		GUIAddress:      "127.0.0.1:8384",
		APIKey:          apiKey,
		LocalDiscovery:  true,
		GlobalDiscovery: true,
		RelaysEnabled:   true,
		NATEnabled:      true,
		NumConnections:  4, // Default to 4 connections for multipath capability
	}, nil
}

// EnsureDirectories creates required configuration and state directories with secure permissions.
func (c *EngineConfig) EnsureDirectories() error {
	if err := os.MkdirAll(c.ConfigDir, 0700); err != nil {
		return fmt.Errorf("failed to create config dir: %w", err)
	}
	if err := os.MkdirAll(c.DataDir, 0700); err != nil {
		return fmt.Errorf("failed to create data dir: %w", err)
	}
	return nil
}
