package discovery_test

import (
	"context"
	"net"
	"testing"
	"time"

	"tandem/core/discovery"
	"tandem/core/pal"
	"tandem/core/pal_linux"
)

func TestPerInterfaceBroadcastCalculation(t *testing.T) {
	// 192.168.1.50 / 24 -> Broadcast should be 192.168.1.255
	ip := net.ParseIP("192.168.1.50")
	mask := net.CIDRMask(24, 32)
	ipnet := &net.IPNet{IP: ip, Mask: mask}

	iface := pal.Iface{
		Name:  "wlan0",
		Kind:  pal.IfaceKindWiFi,
		Addrs: []net.Addr{ipnet},
	}

	adapter := pal_linux.NewLinuxAdapter()
	targets := adapter.BroadcastTargets(iface)

	if len(targets) != 1 {
		t.Fatalf("expected 1 broadcast target, got %d", len(targets))
	}
	expected := "192.168.1.255"
	if targets[0].String() != expected {
		t.Errorf("broadcast target mismatch: got %s, expected %s", targets[0].String(), expected)
	}
}

func TestDiscoveryAnnouncementPacket(t *testing.T) {
	ann := discovery.Announcement{
		DeviceID:   "TANDEM-TEST-1234",
		DeviceName: "Alice’s Laptop",
		Port:       22000,
		Addresses:  []string{"192.168.1.50:22000"},
		Timestamp:  time.Now().Unix(),
	}

	payload, err := ann.Marshal()
	if err != nil {
		t.Fatalf("Marshal failed: %v", err)
	}

	parsed, err := discovery.UnmarshalAnnouncement(payload)
	if err != nil {
		t.Fatalf("Unmarshal failed: %v", err)
	}

	if parsed.DeviceID != ann.DeviceID || parsed.Port != ann.Port {
		t.Errorf("parsed announcement mismatch: %+v vs %+v", parsed, ann)
	}
}

func TestDiscoverySelfTest(t *testing.T) {
	dt := discovery.NewService(discovery.Config{
		DeviceID:   "TEST-SELF",
		DeviceName: "Localhost Tester",
		Port:       22000,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// Self-test should verify whether broadcast/multicast transmission functions
	res := dt.RunSelfTest(ctx)
	t.Logf("Discovery self-test result: Passed=%v, Notes=%s", res.DiscoveryWorks, res.Notes)
}

func TestFlowEDetection(t *testing.T) {
	// Simulate Flow E: Same network subnet but zero discovery packets received
	flow := discovery.DetectFlow(discovery.NetworkEnvironment{
		SameSubnet:           true,
		DiscoveryPacketsSeen: 0,
		HasInternet:          false,
	})

	if flow.Kind != discovery.FlowEBlockedDiscovery {
		t.Errorf("expected FlowEBlockedDiscovery, got: %v", flow.Kind)
	}
	if flow.ActionRequired != "Make a hotspot" {
		t.Errorf("expected hotspot action, got: %s", flow.ActionRequired)
	}
	if flow.Explanation == "" {
		t.Errorf("expected non-empty explanation message")
	}
}
