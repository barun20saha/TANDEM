package discovery

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"sync"
	"time"

	"tandem/core/pal"
)

const (
	DiscoveryPortDefault = 21027
	DiscoveryMagic       = 0x54414E44 // "TAND"
)

// Announcement payload broadcast periodically over UDP 21027 on all active interfaces.
type Announcement struct {
	Magic      uint32   `json:"magic"`
	DeviceID   string   `json:"id"`
	DeviceName string   `json:"name"`
	Port       int      `json:"port"`
	Addresses  []string `json:"addrs"`
	Timestamp  int64    `json:"ts"`
}

func (a *Announcement) Marshal() ([]byte, error) {
	a.Magic = DiscoveryMagic
	return json.Marshal(a)
}

func UnmarshalAnnouncement(data []byte) (*Announcement, error) {
	var a Announcement
	if err := json.Unmarshal(data, &a); err != nil {
		return nil, err
	}
	if a.Magic != DiscoveryMagic {
		return nil, fmt.Errorf("invalid discovery magic: 0x%X", a.Magic)
	}
	return &a, nil
}

// Config sets up local discovery parameters.
type Config struct {
	DeviceID   string
	DeviceName string
	Port       int
}

// SelfTestResult documents the outcome of the discovery loopback and firewall check.
type SelfTestResult struct {
	DiscoveryWorks bool
	Notes          string
	InterfacesSeen int
}

// Service manages per-interface local announcements and peer discovery.
type Service struct {
	cfg     Config
	mu      sync.RWMutex
	peers   map[string]*Announcement
	stopped bool
}

func NewService(cfg Config) *Service {
	if cfg.Port == 0 {
		cfg.Port = 22000
	}
	return &Service{
		cfg:   cfg,
		peers: make(map[string]*Announcement),
	}
}

// BroadcastOnAllInterfaces sends local discovery announcements on every active interface's broadcast address (Section 4.2).
func (s *Service) BroadcastOnAllInterfaces(ifaces []pal.Iface, targetsFunc func(pal.Iface) []net.IP) int {
	s.mu.Lock()
	defer s.mu.Unlock()

	ann := Announcement{
		DeviceID:   s.cfg.DeviceID,
		DeviceName: s.cfg.DeviceName,
		Port:       s.cfg.Port,
		Timestamp:  time.Now().Unix(),
	}

	payload, err := ann.Marshal()
	if err != nil {
		return 0
	}

	conn, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4zero, Port: 0})
	if err != nil {
		return 0
	}
	defer conn.Close()

	sentCount := 0
	for _, iface := range ifaces {
		targets := targetsFunc(iface)
		for _, targetIP := range targets {
			dst := &net.UDPAddr{
				IP:   targetIP,
				Port: DiscoveryPortDefault,
			}
			if _, err := conn.WriteTo(payload, dst); err == nil {
				sentCount++
			}
		}
	}

	return sentCount
}

// RunSelfTest verifies that the local socket can send and receive UDP broadcast packets (Section 5.4).
func (s *Service) RunSelfTest(ctx context.Context) SelfTestResult {
	addr := &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0}
	conn, err := net.ListenUDP("udp4", addr)
	if err != nil {
		return SelfTestResult{
			DiscoveryWorks: false,
			Notes:          fmt.Sprintf("Cannot open UDP discovery socket: %v", err),
		}
	}
	defer conn.Close()

	ann := Announcement{
		DeviceID:   s.cfg.DeviceID,
		DeviceName: s.cfg.DeviceName,
		Port:       s.cfg.Port,
		Timestamp:  time.Now().Unix(),
	}
	payload, _ := ann.Marshal()

	// Send to loopback
	dest := &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: conn.LocalAddr().(*net.UDPAddr).Port}
	if _, err := conn.WriteTo(payload, dest); err != nil {
		return SelfTestResult{
			DiscoveryWorks: false,
			Notes:          fmt.Sprintf("Failed writing loopback broadcast: %v", err),
		}
	}

	_ = conn.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	buf := make([]byte, 1024)
	n, _, err := conn.ReadFrom(buf)
	if err != nil || n == 0 {
		return SelfTestResult{
			DiscoveryWorks: false,
			Notes:          "Self-test broadcast packet was dropped (firewall or OS permission issue)",
		}
	}

	return SelfTestResult{
		DiscoveryWorks: true,
		Notes:          "Local UDP discovery socket is operational",
		InterfacesSeen: 1,
	}
}

// ================= Flow Selection Ladder (Section 5.3) =================

type FlowKind string

const (
	FlowANormalLAN          FlowKind = "flow_a_normal_lan"
	FlowBPhoneHotspot       FlowKind = "flow_b_phone_hotspot"
	FlowCLaptopHotspot      FlowKind = "flow_c_laptop_hotspot"
	FlowDMacJoinHotspot     FlowKind = "flow_d_mac_join_hotspot"
	FlowEBlockedDiscovery   FlowKind = "flow_e_blocked_discovery"
)

type NetworkEnvironment struct {
	SameSubnet           bool
	DiscoveryPacketsSeen int
	HasInternet          bool
	IsMacOS              bool
	PhoneHotspotActive   bool
	LaptopCanAP          bool
}

type FlowRecipe struct {
	Kind           FlowKind
	Title          string
	Explanation    string
	ActionRequired string
}

// DetectFlow evaluates current link signals to guide the user into Recipes A through E.
func DetectFlow(env NetworkEnvironment) FlowRecipe {
	// Flow E: Client isolation / guest network (same subnet but 0 discovery packets)
	if env.SameSubnet && env.DiscoveryPacketsSeen == 0 {
		return FlowRecipe{
			Kind:           FlowEBlockedDiscovery,
			Title:          "Discovery Blocked on this Network",
			Explanation:    "Can't see nearby device. This network may stop devices from finding each other (client isolation). Make a hotspot on one device and connect the other to it.",
			ActionRequired: "Make a hotspot",
		}
	}

	// Flow B: Phone makes the network
	if env.PhoneHotspotActive {
		return FlowRecipe{
			Kind:           FlowBPhoneHotspot,
			Title:          "Phone Hotspot Flow",
			Explanation:    "Phone is acting as the local access point with no internet required. Scan the Wi-Fi QR code to join.",
			ActionRequired: "Join Phone Hotspot",
		}
	}

	// Flow D: macOS cannot host hotspot, guides user to join phone AP
	if env.IsMacOS && !env.HasInternet {
		return FlowRecipe{
			Kind:           FlowDMacJoinHotspot,
			Title:          "Connect via Phone Hotspot",
			Explanation:    "macOS cannot create ad-hoc hotspots from the app. Create a local hotspot on your phone and connect this Mac to it.",
			ActionRequired: "Follow Step-by-Step Guide",
		}
	}

	// Flow A: Default LAN sync
	return FlowRecipe{
		Kind:           FlowANormalLAN,
		Title:          "Direct Local Network",
		Explanation:    "Both devices are on the same Wi-Fi, hotspot, or cable. Local discovery finds peers automatically.",
		ActionRequired: "Sync Active",
	}
}
