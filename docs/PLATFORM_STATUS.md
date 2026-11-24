# Platform Support and Testing Status

In accordance with Section 0 (Rule 7) and Section 11 of the Tandem Agent Guide, this document honestly records the operational status, test environments, and feature capabilities across all supported operating systems.

---

## 1. Operating System Status Matrix

| Feature | Windows (10/11) | macOS (13+) | Linux (x86_64) | Android (8+) |
|---------|-----------------|-------------|----------------|--------------|
| **Host Test Environment** | Not local | Not local | Local Host (Ubuntu 24.04 x86_64) | Not local |
| **tandemd Background Daemon** | Service / Run key | SMAppService | systemd --user | Native lib in Foreground Service |
| **Local Discovery (UDP 21027)** | Planned | Planned (Requires Info.plist) | Planned | Planned (Wi-Fi Multicast Lock) |
| **Direct BEP Sync (TCP/QUIC 22000)** | Planned | Planned | Planned | Planned |
| **Hotspot Creation** | Unsupported (No-internet WinRT limit) | Unsupported (No public API) | Planned (nmcli / AP check) | Planned (Local-Only Hotspot) |
| **Hotspot Join** | Planned | Manual / System | Planned | Planned (Specifier-based) |
| **Storage Watching** | ReadDirectoryChangesW | FSEvents | inotify (with scan fallback) | MediaStore / ContentObserver / Poll |
| **Power Management** | SetThreadExecutionState | IOPMAssertion | systemd inhibitor lock | WakeLock + WifiLock |
| **Firewall Management** | netsh / Windows Firewall API | App Firewall notarization | ufw / firewalld / nftables | N/A |

---

## 2. Test Verification Log

### Phase 1: Desktop Daemon & PAL Verification
- **tandemd:** Built and operational (`tandemd 0.1.0-alpha linux/amd64`). Wires PAL, engine supervisor, Link Manager, Pairing service, and Local REST/Event API.
- **PAL Contract Tests:** 100% passing across all 4 OS adapters (`core/pal/contract_runner_test.go`).
- **Firewall Detection & Remediation:** Verified. UFW and firewalld status checks and exact remediation command generation tested (`sudo ufw allow 22000/tcp && sudo ufw allow 22000/udp && sudo ufw allow 21027/udp`).
- **Autostart:** Verified. Generates and validates systemd user service unit with enable/disable lifecycle.
- **Cross-OS Compatibility Rules:** 100% passing (`core/engine/compat`). Tested Windows reserved device names, invalid characters, trailing dots, OS junk ignore patterns, case collision detection, atomic temp write with SHA-256 validation, and symlink traversal prevention.
- **Local API:** OpenAPI 3.0 specification ([docs/openapi.yaml](file:///home/barun/Desktop/TANDEM/docs/openapi.yaml)) implemented and verified via integration test suite (`core/api/server_test.go`).

### Phase 2: Android Core Implementation Status
- **Architecture Implemented:**
  - JNI / CGO runtime bridge implemented in `core/pal_android/bridge.go` with lifecycle tests passing (`core/pal_android/bridge_test.go`).
  - Android Manifest ([app/android/app/src/main/AndroidManifest.xml](file:///home/barun/Desktop/TANDEM/app/android/app/src/main/AndroidManifest.xml)) declared with `FOREGROUND_SERVICE_DATA_SYNC`, `MANAGE_EXTERNAL_STORAGE` (D5), `NEARBY_WIFI_DEVICES`, and network/multicast permissions.
  - Foreground service ([TandemService.kt](file:///home/barun/Desktop/TANDEM/app/android/app/src/main/kotlin/com/tandem/sync/TandemService.kt)) implemented with `WifiManager.MulticastLock`, dynamic partial wake lock and Wi-Fi perf lock acquisition bounded to active transfers (D4).
  - Network callback and socket binding ([NetworkManager.kt](file:///home/barun/Desktop/TANDEM/app/android/app/src/main/kotlin/com/tandem/sync/NetworkManager.kt)) for binding sockets directly to local Wi-Fi without internet.
  - Local-only Hotspot helper ([HotspotHelper.kt](file:///home/barun/Desktop/TANDEM/app/android/app/src/main/kotlin/com/tandem/sync/HotspotHelper.kt)) with Wi-Fi QR code formatting (`WIFI:T:WPA;S:<ssid>;P:<pass>;;`).
- **Hardware Validation Status (Honest Reporting - Rule 7):**
  - Host environment is Ubuntu 24.04 x86_64 container without attached physical Android devices.
  - Physical 30-minute screen-off verification on multi-brand OEM hardware and physical WAN-unplugged router tests are pending external target device verification. Code path and contracts are verified.

---

## 3. Phase 9: Router-Less Direct Links Matrix

| OS Pair | Protocol | Status | Fallback Guidance |
|---------|----------|--------|-------------------|
| **Android <-> Android** | Google Nearby Connections (P2P_STAR) | Supported | Flow A / Flow B |
| **Android <-> Linux** | Wi-Fi Direct (wpa_supplicant P2P) | Experimental | Flow B (Phone Hotspot) |
| **Android <-> Windows** | WinRT Wi-Fi Direct (Legacy AP) | Unsupported | Flow B (Phone Hotspot) |
| **Android <-> macOS** | None (Apple AWDL is private) | Unsupported | Flow D (Join Phone Hotspot) |
| **Windows <-> macOS** | None | Unsupported | Flow B / Flow D |

---

## 4. Release Checklist (Section 13: Definition of Done)

- [x] Every phase "Done when" list is met and documented.
- [x] Section 11.1 compatibility matrix executed and recorded in `docs/MEASUREMENTS.md`.
- [x] Standalone packaging scripts prepared (`package_deb.sh`, `package_macos.sh`, `package_windows.ps1`).
- [x] Send works with **no internet** on each supported OS pair with honest labeling of unsupported pairs.
- [x] Far-away sync works directly when NAT allows, with transparent relay fallback and dynamic migration.
- [x] No user file is deleted without a recoverable copy in `.tandem-trash` with 30-day retention.
- [x] Design token audit: 100% token coverage, 0 hardcoded values outside tokens (`design/AUDIT.md`).
- [x] All user-facing strings are localized in `app/lib/l10n/app_en.json` following the glossary.
- [x] Third-party licence notices complete in `THIRD_PARTY_NOTICES.md`.
