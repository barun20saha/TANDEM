package discovery

import (
	"fmt"
	"strings"
)

// P2PDirectCapability evaluates router-less direct links per OS pair (Phase 9).
type P2PDirectCapability struct {
	Supported    bool
	Protocol     string
	Experimental bool
	Notes        string
	FallbackFlow FlowKind
}

// CheckRouterlessSupport assesses whether two OS endpoints can establish a link without an access point.
func CheckRouterlessSupport(osA, osB string) P2PDirectCapability {
	normA := strings.ToLower(osA)
	normB := strings.ToLower(osB)

	// Ensure deterministic ordering
	if normA > normB {
		normA, normB = normB, normA
	}

	// 1. Android <-> Android
	if normA == "android" && normB == "android" {
		return P2PDirectCapability{
			Supported:    true,
			Protocol:     "Nearby Connections (P2P_STAR)",
			Experimental: false,
			Notes:        "High-speed automated Wi-Fi Direct and BLE handshake",
			FallbackFlow: FlowANormalLAN,
		}
	}

	// 2. Android <-> Linux
	if normA == "android" && normB == "linux" {
		return P2PDirectCapability{
			Supported:    true,
			Protocol:     "Wi-Fi Direct (wpa_supplicant P2P)",
			Experimental: true,
			Notes:        "Requires Linux wireless card with P2P capability. Experimental.",
			FallbackFlow: FlowBPhoneHotspot,
		}
	}

	// 3. macOS involved with any OS
	if normA == "darwin" || normB == "darwin" || normA == "macos" || normB == "macos" {
		return P2PDirectCapability{
			Supported:    false,
			Protocol:     "None",
			Experimental: false,
			Notes:        "macOS has no public router-less Wi-Fi Direct API (AWDL is private).",
			FallbackFlow: FlowDMacJoinHotspot,
		}
	}

	// 4. Windows involved with non-Windows
	if normA == "windows" || normB == "windows" {
		return P2PDirectCapability{
			Supported:    false,
			Protocol:     "None",
			Experimental: false,
			Notes:        "Windows Wi-Fi Direct requires manual pairing PIN. Use phone hotspot instead.",
			FallbackFlow: FlowBPhoneHotspot,
		}
	}

	return P2PDirectCapability{
		Supported:    false,
		Protocol:     "None",
		Notes:        fmt.Sprintf("Direct router-less link unsupported between %s and %s", osA, osB),
		FallbackFlow: FlowBPhoneHotspot,
	}
}
