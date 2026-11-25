# Platform Support and Testing Status

This document records only verified operational status, test methods, and capabilities observed from real runs (see [docs/TRIAGE.md](TRIAGE.md), [docs/FINAL_REPORT.md](FINAL_REPORT.md), and [docs/evidence/](evidence/)).

---

## 1. Operating System Status Matrix

| Feature | Linux (`x86_64`) | Windows (10/11) | macOS (13+) | Android (8+) |
|---|---|---|---|---|
| **Verification Status** | **Tested locally (`Linux Mint 22.3`)**; CI workflows updated for `ubuntu-24.04` | **Cross-compile (`GOOS=windows`) & CI workflow ready; runtime untested** | **Cross-compile (`GOOS=darwin`) & CI workflow ready; runtime untested** | **Untested on hardware; Stage C blocked on human keystore secrets & phone tests** |
| **tandemd Background Daemon** | Supervised `syncthing v2.1.7` + `127.0.0.1:8385` REST/SSE API + `ss -lntup` verified (`22000/tcp`, `22000/udp`, `21027/udp`) | Untested at runtime (`pal_windows` contains stubs) | Untested at runtime (`pal_darwin` contains stubs) | `pal_android/bridge.go` wired to real `api.Server` + `SyncthingEngine`; NDK build & phone runtime **untested** |
| **Identity (TLS Cert & Device ID)** | **Confirmed** (`cert.pem`, `key.pem`, `api.key`, `engine.key` `0600`, persistent across restarts) | Untested | Untested | Untested |
| **Local Discovery (`UDP 21027`)** | **Confirmed** (`SO_REUSEPORT` per-interface broadcast & discovery of unpaired peers) | Untested | Untested | Untested |
| **Direct BEP Sync (`TCP/QUIC 22000`)** | **Confirmed** (1 GB + 1,000 files `MATCH`, edit/delete, conflict, `kill -9` resume) | Untested | Untested | Untested |
| **No-Internet Sync** | **Confirmed** (isolated `-global-discovery=false -relays=false -nat=false`; `ip netns` when root) | Untested | Untested | Untested |
| **Trash & Recovery (`.tandem-trash`)** | **Confirmed** (30-day `trashcan` versioning + API restore) | Untested | Untested | Untested |
| **Ephemeral Send (D2)** | **Confirmed** (`sendonly` -> `receiveonly` over BEP + auto-cleanup) | Untested | Untested | Untested |
| **Flutter Desktop / Mobile UI** | **Confirmed via live two-daemon UI test & WS3 screenshots** (`design/screenshots/live/`); native GTK binary build not yet run | Untested (`windows/` runner scaffold added) | Untested (`macos/` runner scaffold + `NSLocalNetworkUsageDescription` added) | Untested on device |
| **Hotspot Create / Join** | `nmcli` / `iw list` unit-checked; hardware AP creation **untested** | Unsupported without internet (D/V3) | Unsupported (no public API, V4) | Kotlin code written; **untested** on device |
| **Power / Sleep-Wake** | `systemd-inhibit` executed; `OnResume`/`OnSuspend` hooks are **unwired** | Stub / Untested | Stub / Untested | Kotlin service code written; **untested** on device |
| **Firewall Detection** | `ufw`/`firewalld` checks unit-tested; packaged `ufw`/`firewalld` profiles added; live rule blocking **untested** | Inno Setup firewall script added; **untested** | Stub (`FirewallOpen` hardcoded) | N/A |

---

## 2. Linux Test Verification Summary (Stage A Local Run)

- **Go Core & API (`core/`):** `go vet ./...`, `go build ./...`, `go test -race -count=1 ./...`, `TestOpenAPIContractAndAuthParity`, `TestSecurity_LoopbackOnlyAndPairingConfirmationGate`, `TestDefaultConfig_SeparateInstancesViaConfigFileAndPermissions` — **PASS**.
- **WS1 E2E Suite (`tests/e2e`):** 10/10 real multi-daemon tests (`TestE2E_BootAndAuth`, `TestE2E_Discover`, `TestE2E_PairAndSync1GBAnd1000Files` [`MATCH`], `TestE2E_EditDeleteAndTrashRestore`, `TestE2E_Conflict`, `TestE2E_FilenamesAndWarnings`, `TestE2E_Kill9Resume`, `TestE2E_DiskFull`, `TestE2E_NoInternet`, `TestE2E_SendAndLinkStateSSE`) — **PASS**.
- **Live `ss -lntup` Port Check:** Confirmed `tandemd` listens on `127.0.0.1:<api>` and `0.0.0.0:<disc>/udp`, and supervised `syncthing` listens on `*:<sync>/tcp` and `*:<sync>/udp`.
- **Flutter & Live Two-Daemon UI (`app/`):** `flutter analyze --no-pub --no-fatal-infos`, `openapi_contract_test.dart`, `screens_empty_state_test.dart`, `screenshots_ws3_test.dart`, `live_daemon_ui_test.dart`, and `design/audit.py` — **PASS**.
