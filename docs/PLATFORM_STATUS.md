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

### Current Status: Phase 0 (Ground Truth)
- **Local Host:** Linux sandbox (Ubuntu 24.04 LTS, kernel 7.0.0-42-generic, x86_64).
- **Cross-Platform Host Availability:**
  - Linux: Active local development and verification host.
  - Windows, macOS, Android: Untested on physical target devices in this local session. CI runners or auxiliary devices will be required for hardware-specific tests.
- **Sync Spike Verification:**
  - Syncthing headless protocol contracts and discovery behavior verified against upstream BEP specifications.
