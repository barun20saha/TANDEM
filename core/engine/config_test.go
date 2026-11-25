package engine_test

import (
	"os"
	"path/filepath"
	"testing"

	"tandem/core/engine"
)

func TestDefaultConfig_SeparateInstancesViaConfigFileAndPermissions(t *testing.T) {
	dirA := filepath.Join(t.TempDir(), "nodeA")
	dirB := filepath.Join(t.TempDir(), "nodeB")
	if err := os.MkdirAll(dirA, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(dirB, 0700); err != nil {
		t.Fatal(err)
	}

	if err := os.WriteFile(filepath.Join(dirA, "config.json"), []byte(`{
		"bind": "127.0.0.1:18385",
		"engineGui": "127.0.0.1:18384",
		"syncPort": 24100,
		"discoveryPort": 24127,
		"deviceName": "InstanceA"
	}`), 0600); err != nil {
		t.Fatal(err)
	}

	if err := os.WriteFile(filepath.Join(dirB, "config.json"), []byte(`{
		"bind": "127.0.0.1:18395",
		"engineGui": "127.0.0.1:18394",
		"syncPort": 24200,
		"discoveryPort": 24127,
		"deviceName": "InstanceB"
	}`), 0600); err != nil {
		t.Fatal(err)
	}

	cfgA, err := engine.DefaultConfig(dirA)
	if err != nil {
		t.Fatalf("DefaultConfig(dirA) failed: %v", err)
	}
	cfgB, err := engine.DefaultConfig(dirB)
	if err != nil {
		t.Fatalf("DefaultConfig(dirB) failed: %v", err)
	}

	if cfgA.SyncPort != 24100 || cfgB.SyncPort != 24200 {
		t.Fatalf("expected isolated sync ports 24100/24200, got %d/%d", cfgA.SyncPort, cfgB.SyncPort)
	}
	if cfgA.BindAddr != "127.0.0.1:18385" || cfgB.BindAddr != "127.0.0.1:18395" {
		t.Fatalf("unexpected bind addrs: %s / %s", cfgA.BindAddr, cfgB.BindAddr)
	}
	if cfgA.APIKey == cfgB.APIKey {
		t.Fatalf("two instances generated identical API keys")
	}

	for _, keyPath := range []string{
		filepath.Join(dirA, "api.key"),
		filepath.Join(dirA, "engine.key"),
		filepath.Join(dirB, "api.key"),
		filepath.Join(dirB, "engine.key"),
	} {
		st, err := os.Stat(keyPath)
		if err != nil {
			t.Fatalf("stat %s: %v", keyPath, err)
		}
		if st.Mode().Perm()&0077 != 0 {
			t.Fatalf("key file %s permissions too open: %o", keyPath, st.Mode().Perm())
		}
	}
}
