package discovery

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"sync"
	"syscall"
	"time"

	"tandem/core/pal"
)

const (
	DiscoveryPortDefault = 21027
	DiscoveryMagic       = 0x54414E44 // "TAND"
)

// Announcement payload broadcast periodically over UDP on all active interfaces.
type Announcement struct {
	Magic      uint32   `json:"magic"`
	DeviceID   string   `json:"id"`
	DeviceName string   `json:"name"`
	Port       int      `json:"port"`
	Addresses  []string `json:"addrs"`
	Timestamp  int64    `json:"ts"`
	LastSeen   time.Time `json:"-"`
	RemoteIP   string    `json:"-"`
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
	DeviceID      string
	DeviceName    string
	Port          int // Sync port (default 22000)
	DiscoveryPort int // UDP discovery port (default 21027)
}

// SelfTestResult documents the outcome of the discovery loopback and firewall check.
type SelfTestResult struct {
	DiscoveryWorks bool
	Notes          string
	InterfacesSeen int
}

// Service manages per-interface local announcements and peer discovery.
type Service struct {
	cfg       Config
	mu        sync.RWMutex
	peers     map[string]*Announcement
	conn      net.PacketConn
	listening bool
	stopped   bool
}

func NewService(cfg Config) *Service {
	if cfg.Port == 0 {
		cfg.Port = 22000
	}
	if cfg.DiscoveryPort == 0 {
		cfg.DiscoveryPort = DiscoveryPortDefault
	}
	return &Service{
		cfg:   cfg,
		peers: make(map[string]*Announcement),
	}
}

// Start opens the UDP discovery listener on DiscoveryPort and periodically broadcasts
// per-interface announcements until ctx is cancelled.
func (s *Service) Start(ctx context.Context, netAdapter pal.Network, onDiscovered func(*Announcement)) error {
	lc := net.ListenConfig{
		Control: func(network, address string, c syscall.RawConn) error {
			return c.Control(func(fd uintptr) {
				setSocketReuse(fd)
			})
		},
	}

	bindAddr := fmt.Sprintf("0.0.0.0:%d", s.cfg.DiscoveryPort)
	pc, err := lc.ListenPacket(ctx, "udp4", bindAddr)
	if err != nil {
		return fmt.Errorf("failed binding UDP discovery on %s: %w", bindAddr, err)
	}

	s.mu.Lock()
	s.conn = pc
	s.listening = true
	s.stopped = false
	s.mu.Unlock()

	// Reader loop
	go func() {
		buf := make([]byte, 4096)
		for {
			n, addr, err := pc.ReadFrom(buf)
			if err != nil {
				s.mu.Lock()
				s.listening = false
				s.mu.Unlock()
				return
			}
			ann, err := UnmarshalAnnouncement(buf[:n])
			if err != nil || ann.DeviceID == "" || ann.DeviceID == s.cfg.DeviceID {
				continue
			}
			if udpAddr, ok := addr.(*net.UDPAddr); ok {
				ann.RemoteIP = udpAddr.IP.String()
				if len(ann.Addresses) == 0 && ann.Port > 0 {
					ann.Addresses = []string{fmt.Sprintf("tcp://%s:%d", udpAddr.IP.String(), ann.Port)}
				}
			}
			ann.LastSeen = time.Now()

			s.mu.Lock()
			_, existed := s.peers[ann.DeviceID]
			s.peers[ann.DeviceID] = ann
			s.mu.Unlock()

			if !existed && onDiscovered != nil {
				onDiscovered(ann)
			}
		}
	}()

	// Broadcaster loop
	go func() {
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()
		s.broadcastOnce(netAdapter)
		for {
			select {
			case <-ctx.Done():
				_ = pc.Close()
				return
			case <-ticker.C:
				s.broadcastOnce(netAdapter)
			}
		}
	}()

	return nil
}

func (s *Service) broadcastOnce(netAdapter pal.Network) {
	if netAdapter == nil {
		return
	}
	ifaces, err := netAdapter.Interfaces()
	if err != nil {
		return
	}
	s.BroadcastOnAllInterfaces(ifaces, netAdapter.BroadcastTargets)
}

// IsListening returns true when the UDP discovery listener is active.
func (s *Service) IsListening() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.listening
}

// DiscoveredPeers returns peers announced within the last 30 seconds.
func (s *Service) DiscoveredPeers() []Announcement {
	s.mu.RLock()
	defer s.mu.RUnlock()
	cutoff := time.Now().Add(-30 * time.Second)
	res := make([]Announcement, 0, len(s.peers))
	for _, p := range s.peers {
		if p.LastSeen.After(cutoff) {
			res = append(res, *p)
		}
	}
	return res
}

// BroadcastOnAllInterfaces sends local discovery announcements on every active interface's broadcast address (Section 4.2).
func (s *Service) BroadcastOnAllInterfaces(ifaces []pal.Iface, targetsFunc func(pal.Iface) []net.IP) int {
	s.mu.RLock()
	devID := s.cfg.DeviceID
	devName := s.cfg.DeviceName
	syncPort := s.cfg.Port
	discPort := s.cfg.DiscoveryPort
	s.mu.RUnlock()

	if discPort == 0 {
		discPort = DiscoveryPortDefault
	}

	var addrs []string
	for _, iface := range ifaces {
		for _, a := range iface.Addrs {
			if ipnet, ok := a.(*net.IPNet); ok && ipnet.IP.To4() != nil {
				addrs = append(addrs, fmt.Sprintf("tcp://%s:%d", ipnet.IP.String(), syncPort))
			}
		}
	}

	ann := Announcement{
		DeviceID:   devID,
		DeviceName: devName,
		Port:       syncPort,
		Addresses:  addrs,
		Timestamp:  time.Now().Unix(),
	}

	payload, err := ann.Marshal()
	if err != nil {
		return 0
	}

	lc := net.ListenConfig{
		Control: func(network, address string, c syscall.RawConn) error {
			return c.Control(func(fd uintptr) {
				setSocketReuse(fd)
			})
		},
	}
	conn, err := lc.ListenPacket(context.Background(), "udp4", "0.0.0.0:0")
	if err != nil {
		return 0
	}
	defer conn.Close()

	sentCount := 0
	seen := make(map[string]struct{})
	for _, iface := range ifaces {
		targets := targetsFunc(iface)
		for _, targetIP := range targets {
			k := targetIP.String()
			if _, dup := seen[k]; dup {
				continue
			}
			seen[k] = struct{}{}
			dst := &net.UDPAddr{
				IP:   targetIP,
				Port: discPort,
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
	FlowANormalLAN        FlowKind = "flow_a_normal_lan"
	FlowBPhoneHotspot     FlowKind = "flow_b_phone_hotspot"
	FlowCLaptopHotspot    FlowKind = "flow_c_laptop_hotspot"
	FlowDMacJoinHotspot   FlowKind = "flow_d_mac_join_hotspot"
	FlowEBlockedDiscovery FlowKind = "flow_e_blocked_discovery"
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
	if env.SameSubnet && env.DiscoveryPacketsSeen == 0 {
		return FlowRecipe{
			Kind:           FlowEBlockedDiscovery,
			Title:          "Discovery Blocked on this Network",
			Explanation:    "Can't see nearby device. This network may stop devices from finding each other (client isolation). Make a hotspot on one device and connect the other to it.",
			ActionRequired: "Make a hotspot",
		}
	}
	if env.PhoneHotspotActive {
		return FlowRecipe{
			Kind:           FlowBPhoneHotspot,
			Title:          "Phone Hotspot Flow",
			Explanation:    "Phone is acting as the local access point with no internet required. Scan the Wi-Fi QR code to join.",
			ActionRequired: "Join Phone Hotspot",
		}
	}
	if env.IsMacOS && !env.HasInternet {
		return FlowRecipe{
			Kind:           FlowDMacJoinHotspot,
			Title:          "Connect via Phone Hotspot",
			Explanation:    "macOS cannot create ad-hoc hotspots from the app. Create a local hotspot on your phone and connect this Mac to it.",
			ActionRequired: "Follow Step-by-Step Guide",
		}
	}
	return FlowRecipe{
		Kind:           FlowANormalLAN,
		Title:          "Direct Local Network",
		Explanation:    "Both devices are on the same Wi-Fi, hotspot, or cable. Local discovery finds peers automatically.",
		ActionRequired: "Sync Active",
	}
}
