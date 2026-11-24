//go:build linux

package pal_linux_test

import (
	"testing"

	"tandem/core/pal_linux"
	pal_contract "tandem/core/pal"
)

func TestLinuxPALContract(t *testing.T) {
	adapter := pal_linux.NewLinuxAdapter()

	// Verify all interfaces are satisfied by the adapter
	var _ pal_contract.Network = adapter
	var _ pal_contract.Firewall = adapter
	var _ pal_contract.Hotspot = adapter
	var _ pal_contract.Storage = adapter
	var _ pal_contract.Lifecycle = adapter
	var _ pal_contract.Autostart = adapter
	var _ pal_contract.Notifier = adapter

	// Run standard contract tests
	pal_contract_test := func(t *testing.T) {
		ifaces, err := adapter.Interfaces()
		if err != nil {
			t.Fatalf("Interfaces() error: %v", err)
		}
		t.Logf("Found %d network interfaces", len(ifaces))

		cap := adapter.Capability()
		t.Logf("Hotspot capability: CanCreate=%v, CanJoin=%v, Notes=%s", cap.CanCreate, cap.CanJoin, cap.Notes)

		storageCaps := adapter.Capabilities(pal_contract.FolderRef{Path: "."})
		if !storageCaps.CaseSensitive {
			t.Errorf("Linux filesystem must report CaseSensitive=true")
		}
		if storageCaps.MaxPath <= 0 {
			t.Errorf("MaxPath must be positive")
		}

		fwStatus, err := adapter.Status([]pal_contract.Port{
			{Port: 22000, Protocol: "tcp"},
			{Port: 22000, Protocol: "udp"},
			{Port: 21027, Protocol: "udp"},
		})
		t.Logf("Firewall status: %v (err=%v)", fwStatus, err)

		remed := adapter.Remediation([]pal_contract.Port{{Port: 22000, Protocol: "tcp"}})
		if remed.Command == "" {
			t.Errorf("Remediation command must not be empty")
		}

		release := adapter.HoldAwake("test")
		if release == nil {
			t.Errorf("HoldAwake must return non-nil release function")
		}
		release()
	}

	t.Run("ContractSuite", pal_contract_test)

	t.Run("FirewallRemediationText", func(t *testing.T) {
		ports := []pal_contract.Port{
			{Port: 22000, Protocol: "tcp"},
			{Port: 22000, Protocol: "udp"},
			{Port: 21027, Protocol: "udp"},
		}
		remed := adapter.Remediation(ports)
		if remed.Description == "" {
			t.Errorf("expected non-empty remediation description")
		}
		if remed.Command != "sudo ufw allow 22000/tcp && sudo ufw allow 22000/udp && sudo ufw allow 21027/udp" {
			t.Errorf("unexpected remediation command: %s", remed.Command)
		}
	})

	t.Run("AutostartServiceFile", func(t *testing.T) {
		t.Setenv("XDG_CONFIG_HOME", t.TempDir())
		err := adapter.Enable()
		if err != nil {
			t.Fatalf("Enable autostart failed: %v", err)
		}
		if !adapter.Enabled() {
			t.Errorf("expected Enabled() to return true after Enable()")
		}
		_ = adapter.Disable()
		if adapter.Enabled() {
			t.Errorf("expected Enabled() to return false after Disable()")
		}
	})
}
