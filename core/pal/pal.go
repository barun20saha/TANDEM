package pal

import (
	"context"
	"net"
)

// IfaceKind classifies the network physical/logical link type.
type IfaceKind string

const (
	IfaceKindWiFi     IfaceKind = "wifi"
	IfaceKindEthernet IfaceKind = "ethernet"
	IfaceKindCellular IfaceKind = "cellular"
	IfaceKindUSB      IfaceKind = "usb"
	IfaceKindHotspot  IfaceKind = "hotspot"
)

// Iface represents a network interface and its capabilities.
type Iface struct {
	Name                 string
	Kind                 IfaceKind
	Addrs                []net.Addr
	HasValidatedInternet bool
	IsMetered            bool
	IsLocalOnly          bool
}

// NetworkChangeType denotes the kind of network state transition.
type NetworkChangeType string

const (
	NetworkChangeAdd             NetworkChangeType = "add"
	NetworkChangeRemove          NetworkChangeType = "remove"
	NetworkChangeAddressChange   NetworkChangeType = "address_change"
	NetworkChangeInternetChange  NetworkChangeType = "internet_change"
)

// NetworkChange details an event observed by the network watcher.
type NetworkChange struct {
	Type  NetworkChangeType
	Iface Iface
}

// Network abstracts link enumeration, event watching, socket binding, and discovery.
type Network interface {
	Interfaces() ([]Iface, error)
	Watch(ctx context.Context) <-chan NetworkChange
	DialFrom(i Iface, network, addr string) (net.Conn, error)
	ListenOn(i Iface, network, addr string) (net.Listener, error)
	BroadcastTargets(i Iface) []net.IP
}

// Port specifies a transport port and protocol.
type Port struct {
	Port     int
	Protocol string // "tcp" or "udp"
}

// FirewallState represents inbound firewall allowance status.
type FirewallState string

const (
	FirewallOpen    FirewallState = "open"
	FirewallBlocked FirewallState = "blocked"
	FirewallUnknown FirewallState = "unknown"
)

// Remediation provides user instructions or system commands to unblock ports.
type Remediation struct {
	Description      string
	Command          string
	PrivilegedAction string
}

// Firewall manages inspection and user-consented remediation of OS firewall rules.
type Firewall interface {
	Status(ports []Port) (FirewallState, error)
	Remediation(ports []Port) Remediation
}

// HotspotCap describes the OS/hardware hotspot capabilities.
type HotspotCap struct {
	CanCreate       bool
	CanJoin         bool
	NeedsUserAction bool
	Notes           string
}

// HotspotInfo contains connection parameters for an active local hotspot.
type HotspotInfo struct {
	SSID       string
	Passphrase string
	GatewayIP  net.IP
	QRPayload  string
}

// Hotspot manages ad-hoc local-only networks.
type Hotspot interface {
	Capability() HotspotCap
	Create() (HotspotInfo, error)
	Join(ssid, pass string) error
	Stop() error
}

// FolderRef identifies a selected filesystem folder.
type FolderRef struct {
	ID   string
	Path string
	URI  string
}

// StorageCaps documents filesystem limits and capabilities for a selected folder.
type StorageCaps struct {
	CanWatch      bool
	CanRename     bool
	CaseSensitive bool
	MaxPath       int
	Notes         string
}

// Storage handles folder selection and capability reporting across OS sandboxes.
type Storage interface {
	PickFolder() (FolderRef, error)
	Capabilities(f FolderRef) StorageCaps
}

// Lifecycle provides power management assertions and sleep/wake hooks.
type Lifecycle interface {
	HoldAwake(reason string) (release func())
	OnResume(func())
	OnSuspend(func())
}

// Autostart manages launch-at-login or system service configuration.
type Autostart interface {
	Enable() error
	Disable() error
	Enabled() bool
}

// Notification defines a user-facing system notification.
type Notification struct {
	Title string
	Body  string
	Tag   string
}

// Notifier displays OS desktop or mobile notifications.
type Notifier interface {
	Notify(n Notification) error
}
