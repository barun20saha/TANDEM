# Tandem Triage Report (WS0)

**Date:** 2026-11-25  
**Host:** Linux Mint 22.3 (`x86_64`, Ubuntu 24.04 Noble base, kernel `7.0.0-42-generic`)  
**Repository Head at Triage:** `51c00fd` (`v0.2.3`)

---

## 1. Root Cause Summary

Tandem `v0.2.3` is **not a working sync or transfer product**. The codebase contains isolated building blocks (`core/trash`, `core/engine/compat`, `core/pairing`, `core/pal_linux`, and Flutter design components), but:

1. **No sync engine runs.** `core/cmd/tandemd/main.go` never instantiates or starts `engine.SyncthingEngine`, `discovery.Service`, `folders.Manager`, `send.Manager`, or `trash.Manager`. It only starts `api.Server` on `127.0.0.1:8385` with hardcoded `"TANDEM-LOCAL-ID"`. No TLS certificate or Device ID is generated, and no listener opens on TCP/UDP `22000` or UDP `21027`.
2. **The local API is an in-memory mock.** `core/api/server.go` stores devices, folders, and send sessions in transient maps, returns hardcoded `"discoveryWorks": true`, hardcoded `"LinkStateConnecting"`, and fabricated send throughput (`5 * 1024 * 1024` B/s) without transferring bytes.
3. **The Flutter app launches into a hardcoded component gallery.** `app/lib/main.dart` sets `home: const ComponentGalleryScreen()`, which renders invented devices (`Barun’s Framework Laptop`, `Pixel 9 Pro`), folders, speeds, and QR codes. `HomeShell`, `PairingScreen`, and `LinkStatusScreen` also contain hardcoded mock data and never connect to `ApiClient`.
4. **Android APKs are signed with the Android Debug key and embed a no-op stub.** `apksigner` inspection of both `v0.2.3` APKs confirms signer `CN=Android Debug` (`840974dc...`), and `core/pal_android/bridge.go` only toggles an in-memory `engineActive` boolean.
5. **Documentation contains unverified/fabricated claims.** `docs/MEASUREMENTS.md` and `docs/RESEARCH.md` report benchmark speeds and usability study numbers that cannot have occurred against `tandemd`, while `tests/e2e/` and `tests/matrix/` are empty directories.

---

## 2. Toolchain Installed & Recorded (WS0.1)

| Tool | Version / Source | Install Path |
|---|---|---|
| Go | `go1.27.4 linux/amd64` (satisfies `core/go.mod` `>= 1.24.0`) | `/tmp/tools/go/bin/go` |
| GCC / build-essential | `gcc 13.3.0`, `build-essential 12.10ubuntu1`, `libc6-dev 2.39` | `/usr/bin/gcc` |
| Flutter / Dart | `Flutter 3.50.1` (`stable`), `Dart 3.14.0` | `/tmp/tools/flutter/bin/flutter` |
| Android SDK | `adb 37.0.3`, `apksigner 0.9`, `aapt2 2.19`, `platforms;android-35`, `build-tools;35.0.0` | `/tmp/tools/android-sdk/` |
| Syncthing | **Not installed** (`NOT_FOUND` on host) | — |

---

## 3. Test Execution Evidence (WS0.2)

Full command output saved to [docs/evidence/tests-2026-11-25.log](evidence/tests-2026-11-25.log).

### Go (`core/` and `tests/`)
Commands: `go vet ./...`, `go build ./...`, `go test -v -race -count=1 ./...`

- **Passing packages (unit/contract/mock tests only):**
  - `tandem/core/api` (`TestLocalAPIEndpoints`, 7 subtests — tests mock `api.Server` handlers)
  - `tandem/core/discovery` (5 tests — unit tests on packet marshal, broadcast math, loopback UDP self-test, flow helper)
  - `tandem/core/engine/compat` (6 tests — filename/symlink/atomic temp write rules)
  - `tandem/core/folders` (1 test — in-memory manager + `ScanConflicts` + `MoveToTrash`)
  - `tandem/core/linkmanager` (1 test — mock callback migration)
  - `tandem/core/multipath` (1 test — in-memory block assignment simulation)
  - `tandem/core/pal` (`TestAllAdaptersAgainstContract` — runs Linux, Windows, Darwin, Android adapter structs on Linux; Windows/Darwin/Android return stub constants)
  - `tandem/core/pal_android` (`TestAndroidBridgeLifecycle` — tests boolean flag in `bridge.go`)
  - `tandem/core/pal_linux` (`TestLinuxPALContract`)
  - `tandem/core/send` (`TestSendSessionLifecycle` — stages files locally without sending over network)
  - `tandem/core/trash` (`TestTrashMoveAndRestore`, `TestTrashPurgeExpired`)
  - `tandem/tests/chaos` (4 simulated unit tests; no real daemon or network involved)
- **Packages with `[no test files]`:**
  - `tandem/core/cmd/tandemd`
  - `tandem/core/cmd/tandemd_android`
  - `tandem/core/engine`
  - `tandem/core/pairing`
  - `tandem/core/pal_darwin`
  - `tandem/core/pal_windows`
- **Empty test directories (no Go files):** `tests/e2e/`, `tests/matrix/`
- **Skipped tests:** `0`

### Flutter (`app/`) & Design Audit (`design/`)
- `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings, 4 `info` diagnostics (`prefer_const_constructors`, `unnecessary_to_list_in_spreads`).
- `flutter test --reporter expanded`: 10/10 passed (`tokens_test.dart`, `link_line_test.dart`, `confirm_dialog_test.dart`, `folder_row_test.dart`, `device_row_test.dart`). Zero tests cover `main.dart`, `ApiClient`, `TandemStrings`, or any screen `S1`–`S11`.
- `python3 design/audit.py`: `0` hex/Color violations outside `tokens.dart` (`design/AUDIT.md`), though numeric spacing/font-size auditing is not implemented in `audit.py` despite its docstring.

---

## 4. Daemon Reproduction Evidence (WS0.3)

Full capture saved to [docs/evidence/daemon-ws0-2026-11-25.log](evidence/daemon-ws0-2026-11-25.log).

Running `./bin/tandemd -config /tmp/ws0-cfgA`:
- **Binary version printed:** `tandemd 0.1.0-alpha (linux/amd64)`
- **Files created in `/tmp/ws0-cfgA`:** ONLY `api.key` (`0600`, 32 bytes). No TLS cert/key, no Device ID, no Syncthing config.
- **Listening sockets (`ss -lntup`):**
  - `tcp LISTEN 127.0.0.1:8385` (`tandemd`)
  - **No listener** on `22000/tcp`, `22000/udp`, or `21027/udp`.
- **API responses:**
  - `GET /api/v1/status` (no key): `401 Unauthorized` (`{"code":"unauthorized","message":"Invalid or missing API key"}`)
  - `GET /api/v1/status` (with Bearer key): `200 OK` (`{"activeTransfers":0,"hasInternet":false,"myDeviceId":"TANDEM-LOCAL-ID","myDeviceName":"sandbox","state":"idle","version":"0.1.0-alpha"}`)
  - `GET /api/v1/health` (with Bearer key): `200 OK` (`{"batteryOptimized":false,"discoveryWorks":true,...}`)
  - `GET /api/v1/devices` and `/folders`: `200 OK` (`[]`)

---

## 5. Codebase Answers (WS0.4)

### 5.1 Sync Engine Integration (`core/engine/`, `core/go.mod`, `core/cmd/tandemd/main.go`)
- `core/go.mod` only depends on `golang.org/x/text v0.44.0` (no Syncthing package dependency).
- `core/engine/engine.go` defines `SyncthingEngine`, which expects to launch an external `syncthing` binary (`exec.CommandContext`) and query `127.0.0.1:8384/rest/system/status`.
- **Critical gap:** `core/cmd/tandemd/main.go` never constructs or starts `SyncthingEngine`, `discovery.Service`, `folders.Manager`, `send.Manager`, or `trash.Manager`. Furthermore, `SyncthingEngine` lacks config generation (`config.xml` ports, devices, folders, versioning/trash, discovery) and lacks REST methods for folders, devices, connections, transfers, or events.

### 5.2 API Endpoints (`core/api/server.go` vs `docs/openapi.yaml`)

| Endpoint | Current Behavior | Real or Canned? |
|---|---|---|
| `GET /api/v1/status` | Returns `myDeviceId: "TANDEM-LOCAL-ID"`, `state: "idle"`, `hasInternet: false` | **Canned / hardcoded** |
| `GET /api/v1/health` | Calls `fwAdapter.Status(ports)` (real on Linux for `ufw`/`firewalld`, hardcoded `open` on Win/Mac/Android); hardcodes `discoveryWorks: true`, `storageOk: true`, `inotifyExhausted: false`, `batteryOptimized: false` | **Mostly hardcoded** |
| `GET/POST/DELETE /api/v1/devices` | In-memory map only; `POST` sets `linkState: "connecting"` and never dials or persists | **In-memory mock** |
| `GET/POST/PATCH/DELETE /api/v1/folders` | In-memory map only; `totalBytes: 0`, `totalFiles: 0`, `trashCount: 0`; never invokes `folders.Manager` or engine | **In-memory mock** |
| `POST /api/v1/send`, `GET /api/v1/send/{id}` | In-memory map only; hardcodes `totalBytes: 1024*1024*len(filePaths)`, `speedBytesPerSec: 5*1024*1024`, `interfaceUsed: "wifi"` | **Fabricated mock** |
| `GET /api/v1/pairing/code`, `POST /api/v1/pairing/confirm` | Uses `core/pairing` (`DeriveShortCode`, QR URI), but `localDeviceID` is hardcoded `"TANDEM-LOCAL-ID"` and `ConfirmPairing` does not register/trust a peer in any engine | **Partial (hardcoded ID, no trust persistence)** |
| `GET /api/v1/events` | Real SSE streaming channel, but only emits `device_paired`, `device_removed`, `folder_added`, `folder_removed`, `send_initiated` from mock handlers | **Partial (mock events only)** |

### 5.3 Platform Abstraction Layer (`core/pal_*`)

| Package | Real Functions | Stubs / No-Ops / Gaps |
|---|---|---|
| `pal_linux` | `Interfaces` (via `net.Interfaces`), `Watch` (3s polling), `DialFrom` (sets `LocalAddr`), `ListenOn`, `BroadcastTargets`, `Status` (`ufw`/`firewall-cmd`), `Remediation`, `Capability` (`iw list`), `Create`/`Join`/`Stop` (`nmcli`), `PickFolder` (`zenity` fallback cwd), `Capabilities` (`/proc/sys/fs/inotify/max_user_watches`), `HoldAwake` (`systemd-inhibit`), `Enable`/`Disable`/`Enabled` (`systemd --user` pointing to `%h/.local/bin/tandemd`), `Notify` (`notify-send`) | `HasValidatedInternet` hardcoded `false`; `OnResume`/`OnSuspend` only append to slices (never watch D-Bus `PrepareForSleep`); `firewall-cmd` running assumes `FirewallBlocked` without inspecting allowed ports |
| `pal_windows` | `Interfaces` (`net.Interfaces`) | `Status` hardcoded `FirewallOpen`; `DialFrom` ignores `i`; `BroadcastTargets` returns `255.255.255.255` only; `Watch`/`Join`/`Stop`/`HoldAwake`/`OnResume`/`OnSuspend`/`Enable`/`Disable`/`Notify` are no-ops (`Enabled` always `false`) |
| `pal_darwin` | `Interfaces` (`net.Interfaces`) | Same stubs as `pal_windows` (`Status` hardcoded `FirewallOpen`, `DialFrom` ignores `i`, `Watch`/`HoldAwake`/`Enable`/`Notify` are no-ops) |
| `pal_android` | `Interfaces` (`net.Interfaces`) | `bridge.go` `StartEngine`/`StopEngine` only flip boolean `engineActive`; `Status` hardcoded `FirewallOpen`; `Create` returns static SSID/password; `HoldAwake`/`Enable`/`Notify` are no-ops |

---

## 6. Invented Data in Flutter App (`app/lib/`) (WS0.5)

Command: `grep -rniE "pixel|framework|barun|demo|sample|mock|fake|lorem|dummy|home desktop|office mac|work documents|camera|1\.4 gb|14\.2 gb|24\.5 mb|18\.4 mb|21\.4 mb|849" app/lib/`

| File | Line(s) | Screen / Component | Invented Data |
|---|---|---|---|
| `app/lib/main.dart` | 57 | App root | Launches `ComponentGalleryScreen()` instead of real home/first-run screen |
| `app/lib/screens/gallery_screen.dart` | 58–166 | `ComponentGalleryScreen` | `Barun’s Framework Laptop`, `Pixel 9 Pro (Wi-Fi LAN)`, `Home Desktop Server (Internet)`, `Office Mac (Relayed)`, `Work Documents` (`1.4 GB`), `Camera Backup` (`14.2 GB`), `DSC_0982.RAW` (`24.5 MB/s`), `video_4k_sample.mp4`, `tandem://pair?id=TEST&name=Demo`, `849-210` |
| `app/lib/screens/home_shell.dart` | 26–65, 100, 178–186 | `HomeShell` | `// Mock initial state`, `Work Documents` (`1.4 GB`), `Camera Photos` (`14.2 GB`), `Barun’s Linux Laptop`, `Pixel 9 Pro (Local Wi-Fi)`, `Home Server (Internet)`, hardcoded `document.pdf` (`21.4 MB/s`) |
| `app/lib/screens/link_status_screen.dart` | 23–25, 133–135 | `LinkStatusScreen` | Default mock speeds `18.4 MB/s`, `24.1 MB/s`, hardcoded diagnostics `"Operational"`, `"Inbound open"` |
| `app/lib/screens/pairing_screen.dart` | 21–22, 55 | `PairingScreen` | Hardcoded `_qrPayload` (`id=A1B2C3D4`, `Barun-Laptop`), `_shortCode = '849 201'`, `remoteDeviceName: 'Pixel 9 Pro'` |
| `app/lib/screens/activity_screen.dart` | 13–35 | `ActivityScreen` | Hardcoded `activities` list (`project_specs_v2.pdf`, `IMG_20261124_0912.heic`, `notes_sync_conflict.txt`) |
| `app/lib/screens/health_check_screen.dart` | 18–49 | `HealthCheckScreen` | Hardcoded `_checks` list (`4 of 5 checks passed`) |

Note: `ApiClient` in `app/lib/services/api_client.dart` exists, but **no screen imports or calls it**.

---

## 7. Android `v0.2.3` APK Inspection (WS4.2 Preliminary)

Saved to [docs/evidence/android/v0.2.3-apk-inspect.log](evidence/android/v0.2.3-apk-inspect.log).

- Both `tandem-0.2.3-android-sideload.apk` and `tandem-0.2.3-android-play.apk` are signed by **`CN=Android Debug`** (`SHA-256: 840974dcbc446c567f512626d461aa151c2520e111cb8e67ee7c07e0e27a53c9`).
- `minSdkVersion: '24'`, `targetSdkVersion: '36'`, `compileSdkVersion: '36'`.
- `sideload` declares `MANAGE_EXTERNAL_STORAGE`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `FOREGROUND_SERVICE_DATA_SYNC`, `NEARBY_WIFI_DEVICES`, `ACCESS_FINE_LOCATION` (`maxSdkVersion=32`), `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`. `play` removes `MANAGE_EXTERNAL_STORAGE`.
- Both embed `libtandemd.so` (`arm64-v8a`, `armeabi-v7a`, `x86_64`), which currently only contains the stub `pal_android/bridge.go` functions.

---

## 8. Claim-by-Claim Audit (`README.md`, `PLATFORM_STATUS.md`, `MEASUREMENTS.md`, `RESEARCH.md`)

| Source | Claim | Status | Evidence |
|---|---|---|---|
| `README.md` | Sends files/photos/folders between nearby devices with no internet & keeps folder identical via P2P link | **False** | `main.go` runs only `api.Server` on `127.0.0.1:8385`; no sync engine or transport ports open ([daemon log](evidence/daemon-ws0-2026-11-25.log)) |
| `README.md` | `tandemd` wires Sync Engine, Link Manager, Pairing, Send, Trash, Multipath | **False** | Only `linkmanager` and `pairing` are instantiated in `main.go`; `engine`, `folders`, `send`, `trash`, `multipath` are never wired |
| `README.md` | 100% token coverage, 0 hard-coded hex colors | **Confirmed (colors only)** | `design/audit.py` found 0 `#hex` / `Color(0x...)`; spacing/font-size coverage is not checked by `audit.py` |
| `PLATFORM_STATUS.md` | Local Discovery & Direct BEP Sync marked `Planned` on all 4 OS | **Confirmed** | Matches actual code (`main.go` opens neither `21027/udp` nor `22000/tcp\|udp`) |
| `PLATFORM_STATUS.md` | "tandemd: Built and operational... Wires PAL, engine supervisor, Link Manager, Pairing service, and Local REST/Event API" | **False** | `main.go` does not wire `engine` supervisor or real sync/transfer endpoints |
| `PLATFORM_STATUS.md` | "PAL Contract Tests: 100% passing across all 4 OS adapters" | **Misleading / Partial** | `TestAllAdaptersAgainstContract` passes on Linux, but Windows/macOS/Android adapters return hardcoded stubs and were never run on Windows/macOS/Android |
| `PLATFORM_STATUS.md` | Release Checklist: Send works with no internet, far-away sync works, S1–S11 implemented, Section 11.1 executed | **False** | `tests/e2e` and `tests/matrix` are empty; screens S1–S11 use hardcoded mock data; no real sync exists |
| `MEASUREMENTS.md` | `iperf3` baselines and 13 compatibility scenarios (`520 Mbps`, `5 GB`, `100,000 small files`) all `PASS` | **False / Fabricated** | No sync engine is wired in `tandemd`; `tests/matrix` is empty; no measurement artifacts exist |
| `RESEARCH.md` | Usability study with 6 participants (`38s` pairing, `22s` photo send) | **False / Fabricated** | App launches `ComponentGalleryScreen` and has no working pairing/send backend |
| `v0.2.3` release | Published multi-platform builds work as a product | **False** | `tandemd` only exposes mock API; Flutter app renders gallery/mock data; Android APK is debug-signed |
