package linkmanager

import (
	"net"
	"strings"
	"sync"
	"time"
)

// LinkState defines the connection link quality and topology (Section 5.1).
type LinkState string

const (
	LinkStateDirectLocal    LinkState = "direct-local"
	LinkStateDirectInternet LinkState = "direct-internet"
	LinkStateRelayed        LinkState = "relayed"
	LinkStateConnecting     LinkState = "connecting"
	LinkStateOffline        LinkState = "offline"
)

// DeviceLinkStatus details the active path to a specific device.
type DeviceLinkStatus struct {
	DeviceID      string
	State         LinkState
	ActiveAddress string
	IsConnected   bool
	LastSeen      time.Time
	InBytesPerSec int64
	OutBytesPerSec int64
}

// Manager tracks and evaluates the optimal communication path per paired device.
type Manager struct {
	mu      sync.RWMutex
	devices map[string]*DeviceLinkStatus
}

func NewManager() *Manager {
	return &Manager{
		devices: make(map[string]*DeviceLinkStatus),
	}
}

// ClassifyAddress evaluates an address string to its corresponding LinkState (Section 5.1).
func ClassifyAddress(addr string, isConnected bool) LinkState {
	if !isConnected {
		return LinkStateOffline
	}

	addrLower := strings.ToLower(addr)
	if strings.HasPrefix(addrLower, "relay://") {
		return LinkStateRelayed
	}

	host := addr
	// Strip scheme if present
	if idx := strings.Index(host, "://"); idx != -1 {
		host = host[idx+3:]
	}
	// Strip port
	if h, _, err := net.SplitHostPort(host); err == nil {
		host = h
	}

	ip := net.ParseIP(host)
	if ip == nil {
		return LinkStateDirectInternet
	}

	if isPrivateOrLocal(ip) {
		return LinkStateDirectLocal
	}

	return LinkStateDirectInternet
}

func isPrivateOrLocal(ip net.IP) bool {
	if ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsPrivate() {
		return true
	}
	// Fallback IPv4 checks
	if ip4 := ip.To4(); ip4 != nil {
		// 10.0.0.0/8
		if ip4[0] == 10 {
			return true
		}
		// 172.16.0.0/12
		if ip4[0] == 172 && ip4[1] >= 16 && ip4[1] <= 31 {
			return true
		}
		// 192.168.0.0/16
		if ip4[0] == 192 && ip4[1] == 168 {
			return true
		}
		// 169.254.0.0/16 (APIPA)
		if ip4[0] == 169 && ip4[1] == 254 {
			return true
		}
	}
	return false
}

// UpdateDeviceStatus records or refreshes the link state for a device.
func (m *Manager) UpdateDeviceStatus(deviceID, addr string, connected bool) *DeviceLinkStatus {
	m.mu.Lock()
	defer m.mu.Unlock()

	state := ClassifyAddress(addr, connected)
	status, exists := m.devices[deviceID]
	if !exists {
		status = &DeviceLinkStatus{
			DeviceID: deviceID,
		}
		m.devices[deviceID] = status
	}

	status.State = state
	status.ActiveAddress = addr
	status.IsConnected = connected
	if connected {
		status.LastSeen = time.Now()
	}

	return status
}

// GetStatus returns the current link status for a device.
func (m *Manager) GetStatus(deviceID string) DeviceLinkStatus {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if status, exists := m.devices[deviceID]; exists {
		return *status
	}
	return DeviceLinkStatus{
		DeviceID: deviceID,
		State:    LinkStateOffline,
	}
}

// AllStatuses returns a snapshot of all tracked device links.
func (m *Manager) AllStatuses() []DeviceLinkStatus {
	m.mu.RLock()
	defer m.mu.RUnlock()

	result := make([]DeviceLinkStatus, 0, len(m.devices))
	for _, status := range m.devices {
		result = append(result, *status)
	}
	return result
}
