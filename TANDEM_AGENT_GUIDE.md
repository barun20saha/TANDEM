# Tandem: Agent Build Guide

Working title: **Tandem**. Check trademarks before any public use. Do not use "Syncthing" or "Plexo" in the product name.

This file is the single source of truth for the coding agent. Read all of it once, then work **one phase at a time** (Section 7). Sections 8 to 10 (design system, UX copy, handoff) apply to every phase that touches UI.

---

## 0. Rules for the agent

1. **Work in phases.** Each phase has Steps and a "Done when" list. Do not start the next phase until every "Done when" item is verified with evidence (test output, logs, screenshots, or a recorded measurement).
2. **Verify, don't assume.** Anything tagged `VERIFY` must be checked against current upstream docs or source before you rely on it. Your training data may be out of date. Write what you found in `docs/DECISIONS.md`.
3. **Stop at decision gates.** Anything tagged `DECISION` goes to the human. Present the options and your recommendation, then wait.
4. **Small, reviewable commits.** One concern per commit. Never commit secrets, API keys, signing keys or device certificates.
5. **Tests first for the data path.** The sync and transfer path can corrupt or delete user files. Write the test before the change. Never ship a change to the data path without a passing end-to-end test.
6. **Never silently delete user data.** Deletions propagate across devices. Every delete goes through a trash or version store (Section 7, Phase 4).
7. **Honest reporting.** If something does not work on an OS, say so in `docs/PLATFORM_STATUS.md`. Do not mark a phase done on a platform you could not test.
8. **Keep a log.** Maintain `docs/DECISIONS.md` (what and why), `docs/PLATFORM_STATUS.md` (OS by feature matrix) and `docs/MEASUREMENTS.md` (speed and reliability numbers).

---

## 1. Product

**One-line goal:** One app that (a) sends files, photos and folders between nearby devices with no internet, and (b) keeps a folder identical across all your devices, anywhere in the world, over a direct encrypted peer-to-peer link.

**Platforms:** Windows 10/11, macOS, Linux, Android. (iOS is out of scope.)

**Two user-facing modes. Keep them separate in the UI and the code:**

| Mode | What the user thinks | Behaviour |
|------|----------------------|-----------|
| **Send** | "Get this to that device now." | One-off. Pick files, pick a device, done. Nothing keeps syncing afterwards. |
| **Sync** | "This folder lives on all my devices." | Continuous. A change on any device appears on the others. |

**Non-goals for v1:** cloud storage, accounts, a Tandem-hosted server that stores user files, iOS, web access, real-time collaborative editing.

**DECISION D1 (before Phase 4): full copy or on-demand.** Syncthing keeps a full copy of every synced file on every device. A phone with 40 GB of photos will fill a laptop, and the reverse can fill a phone. Recommendation for v1: full copy, plus per-device folder selection and "receive-only" and "send-only" folder types, with a clear storage warning. On-demand placeholder files are a later project.

**DECISION D2 (before Phase 4): how Send works.** Recommendation: implement Send as an ephemeral, single-recipient folder over the same protocol, after a one-time pairing between the two devices. This keeps one protocol and one security model. The alternative is a separate lightweight HTTPS transfer protocol that supports unpaired devices (the LocalSend model). That is more convenient for strangers but doubles the security surface.

---

## 2. What we reuse and what we only learn from

### 2.1 Syncthing (the engine)

Repository: `github.com/syncthing/syncthing`. Written in Go. Licence: **MPL-2.0** (file-level copyleft).

What it provides, and what you must use:

- **Block Exchange Protocol (BEP v1)** over **TLS 1.3**. Device identity is derived from the device's TLS certificate (the "Device ID").
- **Local discovery:** UDP broadcast (IPv4) and multicast (IPv6) announcements on port **21027**. This works with no internet.
- **Global discovery:** public discovery servers, which can be self-hosted.
- **Transports:** TCP and QUIC, default port **22000**. NAT traversal, UPnP and NAT-PMP.
- **Relays:** community relays used when no direct path works. Traffic stays end-to-end encrypted. Relay protocol default port **22067**.
- **REST API** (default GUI address 127.0.0.1:8384, protected by an API key). Use this for the MVP to control the engine.

`VERIFY` before relying on any of these: current stable version, default ports, whether the Go packages under `lib/` are safe to import as a library (they have no API stability promise), and how many parallel connections per device pair are supported.

**Android status:** the official `syncthing-android` app was **archived in December 2024**. Maintained community alternatives exist (Syncthing-Fork and BasicSync). Their ownership has changed hands, so we **own our Android integration** and do not depend on any of them at runtime. Read their source and issues for lessons, especially on storage access and background restrictions.

### 2.2 Plexo (an idea, not a dependency)

Repository: `github.com/anmolkapil/plexo`. TypeScript and Electron. Licence: MIT.

Plexo is a **download manager**. It splits one download across several network connections (for example Wi-Fi plus a USB-tethered phone) and reassembles the parts on disk. It does **not** sync or transfer between your own devices, so its code is not a drop-in component.

What we take from it:

- **Multipath:** use several network interfaces at the same time for one transfer.
- **Per-network accounting:** know which interface carried which blocks, show it, and let the user enable or disable a network.
- **Resilience:** resume after sleep, restart or an IP change.
- **Per-network limits.**

Implementation: Phase 7. If you copy any Plexo code, keep its MIT notice.

### 2.3 Licence rules

- Modified Syncthing source files must stay under MPL-2.0 and be published. Your own new files may use another licence. Keep them in separate files and packages.
- Ship a `THIRD_PARTY_NOTICES.md` listing every dependency and its licence. Audit in Phase 0 and again before release.

---

## 3. Architecture

```
┌────────────────────────── UI (one codebase) ──────────────────────────┐
│ Send screen · Folders · Devices · Link status · Settings              │
│ Talks only to the local daemon API. Never touches the network itself. │
└───────────────────────────────▲───────────────────────────────────────┘
                                │ localhost API (API key, loopback only)
┌───────────────────────────────┴───────────────────────────────────────┐
│ tandemd (Go daemon)                                                   │
│  ├─ Sync engine: Syncthing core (embedded)                            │
│  ├─ Link Manager: picks and watches the best path per device          │
│  ├─ Pairing: QR / code exchange of Device IDs                         │
│  ├─ Send sessions: ephemeral folders                                  │
│  ├─ Multipath scheduler (Phase 7)                                     │
│  └─ Platform Abstraction Layer (PAL), one adapter per OS              │
└───────────────────────────────▲───────────────────────────────────────┘
                                │ OS APIs: sockets, firewall, hotspot,
                                │ storage, background execution, notifications
        Windows adapter · macOS adapter · Linux adapter · Android adapter
```

**Layered wire stack (every OS uses the same one):**

```
L5  App:        folders, Send sessions, pairing
L4  Protocol:   Block Exchange Protocol (BEP), blocks of file data + metadata
L3  Security:   TLS 1.3, mutual auth by device certificate (Device ID)
L2  Transport:  QUIC over UDP, or TCP, on port 22000 (or a relay over TCP)
L1  Network:    IPv4 / IPv6
L0  Link:       Wi-Fi LAN · phone or laptop hotspot · Ethernet · USB tether
                (later: Wi-Fi Direct / Wi-Fi Aware / Nearby Connections)
```

Because every OS speaks the same L1 to L5, **cross-OS compatibility is a matter of making each OS adapter reach L2 reliably.** The per-OS playbook in Section 4 is about that.

### 3.1 Repository layout

```
tandem/
  core/                 Go. tandemd, Link Manager, pairing, send, PAL interfaces
    pal/                Interfaces only (Section 4.1)
    pal_windows/ pal_darwin/ pal_linux/ pal_android/
    engine/             Thin wrapper around embedded Syncthing
    multipath/          Phase 7
  app/                  UI codebase (Flutter recommended; DECISION D3 below)
  design/               tokens.json, component docs, copy deck, handoff specs
  infra/                self-hosted relay + discovery server (docker compose)
  tests/                e2e/, matrix/, chaos/
  docs/                 DECISIONS.md, PLATFORM_STATUS.md, MEASUREMENTS.md
  THIRD_PARTY_NOTICES.md
```

**DECISION D3 (Phase 0): UI toolkit.** Recommendation: one cross-platform UI codebase (Flutter) talking to the Go daemon over the local API. Alternative: Tauri for desktop plus native Kotlin for Android (two UIs, more work, better native feel). Present trade-offs and wait.

---

## 4. Managing each OS: how packets get from one device to another

Goal of this section: make the same L2 to L5 stack (Section 3) reach every other OS reliably. Every OS has different rules for **sockets, firewalls, discovery, hotspots, storage, background execution and power**. Isolate every difference behind the Platform Abstraction Layer (PAL) so the rest of the code never contains `if windows`.

### 4.1 PAL interfaces (write these first, in `core/pal/`)

```go
// Network: what links exist, and how to open sockets on a specific one.
type Network interface {
    Interfaces() ([]Iface, error)   // Iface: Name, Kind (wifi|ethernet|cellular|usb|hotspot),
                                    // Addrs, HasValidatedInternet, IsMetered, IsLocalOnly
    Watch(ctx context.Context) <-chan NetworkChange   // add / remove / address change / validated-internet change
    DialFrom(i Iface, network, addr string) (net.Conn, error)   // socket bound to that interface
    ListenOn(i Iface, network, addr string) (net.Listener, error)
    BroadcastTargets(i Iface) []net.IP                // per-interface broadcast addresses
}

// Firewall: report and (with consent) fix inbound rules.
type Firewall interface {
    Status(ports []Port) (FirewallState, error)       // Open | Blocked | Unknown, with reason
    Remediation(ports []Port) Remediation             // exact steps or a privileged action to offer
}

// Hotspot: create or join a no-internet network where the OS allows it.
type Hotspot interface {
    Capability() HotspotCap                           // CanCreate, CanJoin, NeedsUserAction, Notes
    Create() (HotspotInfo, error)                     // SSID, passphrase, gateway IP, QR payload
    Join(ssid, pass string) error
    Stop() error
}

// Storage: which folders the app may read and write, and how.
type Storage interface {
    PickFolder() (FolderRef, error)
    Capabilities(f FolderRef) StorageCaps             // CanWatch, CanRename, CaseSensitive, MaxPath, Notes
}

// Lifecycle: keep the machine awake during transfers and react to sleep and wake.
type Lifecycle interface {
    HoldAwake(reason string) (release func())
    OnResume(func())
    OnSuspend(func())
}

type Autostart interface{ Enable() error; Disable() error; Enabled() bool }
type Notifier  interface{ Notify(n Notification) error }
```

Rules:

- The daemon calls PAL only. Each OS adapter implements the whole interface. Where an OS cannot do something, return an explicit "not supported" capability. Never return a fake success.
- Write PAL contract tests that every adapter must pass. Run them in CI per OS.

### 4.2 Common socket rules (all OS)

- **Ports:** TCP 22000, UDP 22000 (QUIC), UDP 21027 (local discovery), relay TCP 22067. `VERIFY` against the Syncthing version you embed.
- **Dual stack:** support IPv4 and IPv6. Prefer IPv6 for direct internet connections when both sides have it, since it avoids NAT.
- **Per-interface discovery:** send local-discovery broadcasts **on every active interface**, using that interface's own broadcast address. Do not rely on 255.255.255.255 alone, because multi-homed machines may send it only on the default route. This is what makes hotspots work.
- **Interface binding:** when a feature needs a specific link (multipath, "use hotspot not cellular"), bind the socket to that interface. Do not change the default route.

| OS | How to bind a socket to a specific link | `VERIFY` |
|----|------------------------------------------|---------|
| Linux | bind to the interface's local IP; or `SO_BINDTODEVICE` | privilege rules for `SO_BINDTODEVICE` on the target kernels |
| Windows | bind to the interface's local IP before connect; or `IP_UNICAST_IF` | behaviour on multi-homed hosts |
| macOS | `IP_BOUND_IF` / `IPV6_BOUND_IF` | |
| Android | `Network.bindSocket()` on the `Network` object from `ConnectivityManager` | |

### 4.3 Windows

| Area | What to do |
|------|------------|
| **Process model** | Per-user background process started at login (Task Scheduler or the Run key) plus a tray icon. Optional Windows service for always-on use. A service cannot see per-user mapped drives, so the default is per-user. |
| **Firewall** | Defender Firewall blocks inbound traffic by default, and hotspots and unknown networks are often classed **Public**, which is stricter. The installer (elevated) adds inbound rules **bound to the `tandemd.exe` path** for TCP 22000, UDP 22000 and UDP 21027. Cover Private by default. If the active profile is Public, tell the user and offer a one-click rule. Detect state through the Windows Firewall policy API. |
| **Discovery** | Send broadcasts per interface (Section 4.2). Do not assume the default route is the LAN. |
| **Hotspot** | Mobile Hotspot is available through a WinRT tethering API. `VERIFY`: can it start with **no upstream internet connection**? If not, mark `Hotspot.Create` unsupported on Windows and guide the user to join a phone's hotspot instead. |
| **Storage** | Handle long paths (enable long-path support and use extended-length paths), reserved names (CON, PRN, AUX, NUL, COM1 to 9, LPT1 to 9), trailing dots and spaces, characters `< > : " \| ? *`, and case-insensitive collisions. Files held open by other apps: retry with back-off and never fail the whole sync. |
| **Power** | Hold the system awake during active transfers (execution-state API). On resume, re-announce and reconnect within the target in Section 5.5. |
| **Packaging** | Signed installer (MSI or MSIX). Unsigned builds trigger SmartScreen warnings. |

### 4.4 macOS

| Area | What to do |
|------|------------|
| **Process model** | Menu-bar app plus a login item or LaunchAgent (`SMAppService` on recent macOS, `VERIFY`). The daemon binary **must live inside the signed app bundle**, because privacy permissions attach to the responsible app. |
| **Local Network permission** | Recent macOS versions prompt before an app may use local-network features (`VERIFY` exact version). Add the usage-description keys to `Info.plist`. If the user denies it, **LAN discovery fails silently**. Detect this with a self-test (send and receive a local broadcast) and show a clear fix in the UI that points to System Settings, Privacy & Security, Local Network. |
| **Firewall** | The application firewall prompts on first inbound connection for apps that are not signed. Sign and notarize so the prompt is predictable and does not repeat. |
| **Hotspot** | Internet Sharing has **no public API**. Do not try to automate it. `Hotspot.Capability()` returns `CanCreate=false`. Guide the user to join a phone's hotspot. |
| **Storage** | Desktop, Documents, Downloads, Photos and external volumes are protected by user consent (TCC). Use a user-chosen folder from the system picker and keep a security-scoped bookmark if sandboxed. Offer Full Disk Access instructions as a fallback. **Never sync a `.photoslibrary` package.** Offer a plain folder instead. APFS is case-insensitive by default. File names may be Unicode-normalized differently from other OS (NFD vs NFC), so test names with accents. Ignore `.DS_Store`. |
| **Power** | Use a power assertion during transfers so App Nap and idle sleep do not stall them. Reconnect on wake. |
| **Packaging** | Developer ID signing, hardened runtime, notarization, DMG, and a signed auto-updater. |

### 4.5 Linux

| Area | What to do |
|------|------------|
| **Process model** | systemd **user** unit (`systemctl --user`). Optional linger for headless machines. |
| **Firewall** | ufw, firewalld and nftables vary. Detect which is active. Ship a firewalld service definition and a ufw app profile for the ports in 4.2. **Never change firewall rules silently.** Show the exact command or use a polkit-authorized action with the user's consent. |
| **Discovery** | Per-interface broadcast. Optional mDNS through Avahi as a second discovery path. |
| **Hotspot** | NetworkManager can create a hotspot (`nmcli device wifi hotspot`). `VERIFY` that the Wi-Fi adapter supports AP mode first (`iw list`). Wi-Fi Direct through `wpa_supplicant` is experimental (Phase 9). |
| **Storage** | The kernel's file-watch limit (`fs.inotify.max_user_watches`) is often too low for large trees. When exhausted, fall back to periodic scanning and show a warning with the fix. Linux file systems are case-sensitive, so two files named `A.txt` and `a.txt` will collide on Windows and macOS. Detect and warn before syncing. Do not sync ownership by default. Handle symlinks explicitly. |
| **Power** | Use a systemd inhibitor lock during transfers. Reconnect on the `PrepareForSleep` resume signal. |
| **Packaging** | AppImage, `.deb`, `.rpm`, and Flatpak. `VERIFY` Flatpak network and folder permissions and that broadcast discovery works inside the sandbox. |

### 4.6 Android

| Area | What to do |
|------|------------|
| **Process model** | Run the engine as a **native library inside the app process**, in a **foreground service** with a persistent notification. Do **not** launch it as a separate child executable. Newer Android versions restrict child processes and can kill them. `VERIFY` which foreground-service type is permitted for long-running sync on the target Android versions, and its time limits. |
| **Multicast lock** | Hold a Wi-Fi multicast lock while discovery is active, or the system drops broadcast and multicast packets to save battery and discovery silently fails. |
| **Wi-Fi with no internet** | Android may treat a network with no internet as unusable and prefer mobile data. Register a network callback, find the `Network` for the Wi-Fi link, and **bind sockets to it** (Section 4.2). When joining a hotspot from the app, use the specifier-based join so the system does not change the default network. |
| **Create a hotspot** | The local-only hotspot API creates a no-internet access point with system-generated credentials. Show them as a Wi-Fi QR code (`WIFI:T:WPA;S:<ssid>;P:<pass>;;`) so a laptop can join. `VERIFY` required permissions per Android version (location, or nearby-Wi-Fi-devices on newer versions). |
| **Storage** | Scoped storage blocks arbitrary paths. **DECISION D5:** choose between (a) all-files access (best for photos and arbitrary folders, but restricted on Google Play) and (b) the Storage Access Framework (allowed on Play, but community Syncthing wrappers report performance and rename limits). Recommendation: all-files access for sideload and F-Droid builds, SAF plus MediaStore for a Play build, with a documented feature gap. |
| **Battery** | Doze and App Standby limit background networking. Use a partial wake lock and a high-performance Wi-Fi lock **only during active transfers**. Ask the user to exempt the app from battery optimization with a clear reason. **DECISION D4:** background policy. Recommendation: default "sync while on Wi-Fi or charging", with an "always on" toggle. |
| **Permissions to plan** | Notifications, foreground service, Wi-Fi state and change, multicast state, nearby Wi-Fi devices or location, battery-optimization exemption, all-files access. Request each **at the moment it is needed**, with a one-line reason (Section 9). |
| **Distribution** | Google Play, F-Droid, direct APK. `VERIFY` current Google rules on installing apps from outside Play (developer verification) and plan for them. |
| **Android to Android with no router** | Use Google's Nearby Connections API (Phase 9). It handles Bluetooth, BLE and Wi-Fi under the hood. |

### 4.7 Files must survive every OS (cross-OS file rules)

Implement these in a `core/engine/compat` package, with tests:

1. Detect **case collisions** and **reserved or invalid names** per target OS. Quarantine, rename or warn. Never overwrite.
2. Normalize Unicode for comparison but **preserve the original bytes** where the file system allows it.
3. Write incoming files to a temp name (`.tandem-tmp`), verify hashes, then rename atomically.
4. Ignore OS junk by default: `.DS_Store`, `Thumbs.db`, `desktop.ini`, `.Trash*`, `~$*`.
5. Preserve modification time. Do not sync owner or permissions across OS by default.
6. Never follow symlinks outside the synced folder.
7. A file that cannot be read (locked, no permission) is skipped and reported. It must not stop the sync.

---

## 5. Link Manager: choosing and keeping the best path

The Link Manager decides how each paired device is reached, watches the link, and reports its state to the UI.

### 5.1 Link states (these drive the UI; names are final)

| State | Meaning | UI line style | Label (user-facing) |
|-------|---------|---------------|---------------------|
| `direct-local` | Direct connection on the same LAN, hotspot or cable | solid | Direct, same network |
| `direct-internet` | Direct connection through the internet (NAT traversal worked) | dashed | Direct, over the internet |
| `relayed` | Going through a relay server | dotted | Through a relay (slower) |
| `connecting` | Trying | animated only if motion is allowed, otherwise static | Connecting |
| `offline` | Not reachable | none | Not reachable |

A link state is **always** shown with both a line style **and** a text label. Never use colour alone.

### 5.2 Path selection ladder (try in order, keep the best that works)

1. **Local network.** Local discovery (UDP 21027 per interface) and, where available, mDNS. Connect on TCP or QUIC 22000. Works with no internet.
2. **Known addresses.** Last-seen addresses and any address hints from pairing (Section 6).
3. **Global discovery** (only if internet is available). Query the discovery servers, then try a direct connection with NAT traversal (QUIC hole punching, UPnP or NAT-PMP, IPv6).
4. **Relay.** Last resort. Mark the link `relayed`, and offer "Use your own relay" in Settings (`infra/` ships one).
5. **Router-less direct links** (Phase 9). Nearby Connections, Wi-Fi Aware or Wi-Fi Direct where the OS pair supports it.

Rules:

- **Never require internet for steps 1 and 2.** Do not gate LAN sync on a connectivity check.
- **Upgrade while running.** If a relayed device later becomes reachable directly, migrate to the direct path without restarting the transfer.
- **Prefer the lowest-latency validated link**, but respect user limits (metered networks, "Wi-Fi only").

### 5.3 The "no internet" recipes (what the app actually does)

**Flow A: both devices already on the same Wi-Fi, hotspot or cable.** Local discovery finds the other device. Done.

**Flow B: phone makes the network.**
1. Android creates a local-only hotspot (4.6) and shows a Wi-Fi QR code plus a Tandem pairing QR code.
2. The laptop joins the hotspot (manually or by scanning).
3. Both devices announce on the new interface. The laptop connects to the phone's gateway address from the pairing hint if discovery is blocked. `VERIFY` the gateway address on the tested Android versions. Never hard-code it.

**Flow C: laptop makes the network** (Linux and, if verified, Windows).
1. The laptop creates a hotspot (4.3, 4.5) and shows a Wi-Fi QR code.
2. The phone joins using the specifier-based join (4.6), then binds sockets to that network.

**Flow D: macOS involved.** macOS cannot create a hotspot from the app. The user joins a phone's or other device's network. The app guides this step by step.

**Flow E: discovery blocked** (client isolation, guest Wi-Fi). Detect when devices are on one network but cannot see each other. Say so in plain words and offer the hotspot flow (Flow B). Do not show a generic error.

### 5.4 Detecting what the network can do

On each network change, compute and expose: `hasValidatedInternet`, `isLocalOnly`, `isMetered`, `discoveryWorks` (a self-test: send a broadcast, see if another interface or device receives it), `firewallState`. Show the result in the Link status screen. Treat "no internet" as a normal state, not an error.

### 5.5 Network changes, sleep and recovery

- On any network change or resume: re-announce within **2 seconds**, retry known addresses, and keep partial files for resume. (Proposed target. Measure and record it.)
- A transfer interrupted mid-file resumes from the last verified block. Verify with a test that kills the network during a 5 GB file.
- Back off retries so a dead link does not drain a phone battery.

### 5.6 Speed (far away and nearby)

- Establish a **baseline first**: measure raw link speed with `iperf3` for each test pair and record it in `docs/MEASUREMENTS.md`. Proposed target: on a LAN, Tandem reaches at least 70% of the measured link speed for a single large file. Revisit the number once real measurements exist.
- Compare QUIC and TCP on each OS pair. Choose defaults from measurements, not from opinion.
- Check hashing and disk I/O as bottlenecks, especially on phones.
- Far away: relays cap throughput. Report honestly in the UI which links are relayed, and make self-hosted relay setup easy.

### 5.7 Multipath (the Plexo idea; Phase 7)

Do multipath at the **block-scheduling layer**, not at the packet layer:

1. `VERIFY` first: does the embedded Syncthing version support several parallel connections between the same two devices? If yes, extend that. If not, implement a small scheduler in `core/multipath`.
2. Open one connection **per usable interface** using interface binding (4.2).
3. Distribute block requests across connections. A connection that is faster gets more blocks. A connection that fails returns its blocks to the pool.
4. Record **which interface carried which blocks** (Plexo-style accounting) and show it in the Link status screen.
5. Let the user disable an interface (for example, cellular on a data cap).
6. Safety: blocks are hash-verified, so reassembly cannot corrupt data. Test with deliberately flaky interfaces.

---

## 6. Pairing and security

1. **Identity:** each device has a long-lived TLS certificate. The Device ID is derived from it. Never regenerate it without telling the user.
2. **Pairing by QR code:** the QR code carries the Device ID, a display name, optional address hints (for example a hotspot gateway address) and a one-time nonce. Format (proposed): `tandem://pair?id=<deviceId>&name=<name>&hint=<addr>&n=<nonce>`.
3. **Pairing by code (no camera):** each device shows a short code derived from both Device IDs. The user confirms they match on both screens.
4. **Explicit trust:** a device is trusted only after the user confirms on **both** sides. Folder sharing needs a separate, explicit consent per folder.
5. **Local API:** bind to 127.0.0.1 only, random port, random API key stored in the OS credential store or a file with owner-only permissions. Never expose the sync engine's own web UI.
6. **Privacy on shared networks:** local discovery announces your Device ID to everyone on the LAN. Offer "Hide from this network" in Settings, and turn local announcements off on networks the user marks as untrusted.
7. **Updates:** signed releases only. Verify the signature before applying.
8. **Telemetry:** off by default. If added later, opt-in with a plain explanation.
9. **Untrusted storage devices** (a future always-on server that should not read the data): out of scope for v1. Note it in `docs/DECISIONS.md`.

---

## 7. Phases (do them in order)

### Phase 0: Ground truth

**Steps**
1. Create the repo layout (3.1). Add `docs/` files from Section 0.
2. Audit licences (2.3). Create `THIRD_PARTY_NOTICES.md`.
3. Spike: build and run the current stable Syncthing **headless** on Windows, macOS, Linux and Android (a plain test app). Pair two devices and sync a folder on each OS pair you can access.
4. Resolve every `VERIFY` tag in Sections 2 and 4 that blocks Phase 1 and 2. Record the result.
5. Present decisions **D3** (UI toolkit) to the human and wait.

**Done when**
- Two devices on each available OS pair synced a 1 GB file and 1,000 small files with matching hashes.
- `docs/PLATFORM_STATUS.md` exists and honestly lists what was and was not tested.
- D3 is decided.

### Phase 1: Desktop daemon

**Steps**
1. Implement `tandemd`: embed or launch the engine, apply default config (local discovery on, global discovery on, relays on, GUI off, loopback API with key).
2. Implement the local API the UI will use (devices, folders, link status, events, pairing, send). Document it as OpenAPI.
3. Implement PAL for Windows, macOS and Linux, including firewall checks, autostart and lifecycle.
4. Package and autostart on each desktop OS.

**Done when**
- PAL contract tests pass on all three desktop OS in CI.
- A reboot restores sync with no user action.
- Blocking the ports in the OS firewall produces a correct `firewallState` and remediation text.

### Phase 2: Android core

**Steps**
1. Build the engine as a library inside the Android app (4.6). Run it in a foreground service.
2. Implement multicast lock, network callbacks and socket binding to the Wi-Fi network.
3. Decide **D4** (background policy) and **D5** (storage and distribution) with the human.
4. Implement the storage access path chosen in D5, and test with a 10,000-photo folder.

**Done when**
- Android syncs with each desktop OS over a LAN with **no internet** (router with WAN unplugged).
- The service survives screen-off for 30 minutes on at least two phone brands. Record results.
- Photos from the camera folder appear on a desktop.

### Phase 3: Design system and UI foundation

**Steps**
1. Create `design/tokens.json` from Section 8.1 and generate platform theme code from it.
2. Build every component in Section 8.2 with all states. Document each (variants, states, accessibility, do and don't).
3. Write the copy deck (Section 9) as a localizable string file. No hard-coded user-facing strings in code.
4. Build the app shell and navigation, with light and dark themes, on all four OS.

**Done when**
- Zero hard-coded hex colours or spacing values outside tokens (run the audit in 8.4).
- Every component renders in all states in a component gallery.
- Keyboard-only and screen-reader smoke tests pass on desktop. Touch targets meet the minimum on Android.

### Phase 4: Pairing, folders, Send

**Steps**
1. Decide **D1** (full copy vs on-demand) and **D2** (Send design) with the human.
2. Implement pairing (Section 6) with QR and code flows.
3. Implement folders: add, share with chosen devices, folder types (send and receive, send-only, receive-only), pause, remove.
4. Implement trash and file versioning so a delete or overwrite is recoverable (default: keep 30 days).
5. Implement Send per D2.
6. Implement the cross-OS file rules (4.7) and show conflicts and skipped files clearly.

**Done when**
- A user pairs two devices in under 60 seconds with QR on a first try (usability test with 5 people, Section 11).
- A deleted file is recoverable from the trash on another device.
- Case-collision and reserved-name tests pass on all OS pairs.

### Phase 5: Nearby with no internet

**Steps**
1. Implement per-interface discovery, the discovery self-test and the firewall and permission guidance for each OS (Section 4).
2. Implement Flows A to E (5.3) with UI guidance.
3. Implement the Link status screen (5.1 states, per-interface info).

**Done when**
- All Flows A to E pass on the matrix in Section 11 where the OS supports them.
- Flow E (blocked discovery) shows the specific explanation and the hotspot fix.
- With the router's WAN unplugged and mobile data off, send 5 GB phone to laptop and laptop to phone.

### Phase 6: Far away

**Steps**
1. Verify NAT traversal across several real networks (home, mobile carrier, office).
2. Ship `infra/` (relay and discovery server) with a one-command deploy and docs.
3. Show `direct-internet` and `relayed` states correctly. Test upgrade from relayed to direct.

**Done when**
- Measured results for at least 4 distinct NAT situations are in `docs/MEASUREMENTS.md`.
- A relayed link migrates to direct without restarting the transfer when direct becomes possible.

### Phase 7: Multipath

**Steps** follow Section 5.7.

**Done when**
- Two interfaces together beat the best single interface in a repeatable benchmark, or the result is documented honestly if they do not.
- Killing one interface mid-transfer does not break or corrupt the file.

### Phase 8: Hardening and release

**Steps**
1. Chaos tests: kill the network, kill the process, fill the disk, pull the battery (device), sleep and wake, clock changes.
2. Code signing and notarization on Windows and macOS. Packaging for Linux and Android (per D5).
3. Signed auto-update. Crash reports local only unless the user opts in.
4. Final licence audit. Accessibility audit.

**Done when**
- The test matrix (Section 11) is green, or each failure is a documented known issue.
- A fresh install on each OS works with no developer tools installed.

### Phase 9 (optional): Router-less direct links

**Steps**
1. Android to Android: integrate Nearby Connections.
2. Android to Linux: experiment with Wi-Fi Direct through `wpa_supplicant`. Android to Windows and macOS: `VERIFY` feasibility. Public sources report macOS has no public API.
3. Ship each OS pair **only if it passes end-to-end tests**. Otherwise label it "not supported" in the app.

**Done when**
- Every shipped pair has a passing automated or documented manual test, and `PLATFORM_STATUS.md` says so.

---

## 8. Design system

Source skills: frontend-design (point of view), design-system (tokens, components, audit). The design must feel specific to this product, not like a generic file-sync app.

### 8.1 Concept

The product is about **one folder that exists on several devices, and the connection between them.** So:

- **The one memorable element is the link line** between two devices: solid for direct and nearby, dashed for over the internet, dotted for relayed (Section 5.1). Spend boldness here. Keep everything else quiet.
- The first thing on screen is **the user's folder and where it currently lives**, not a logo, a stat or a gradient.
- Structure carries information. A border, divider or label appears only when it tells the user something.

**Avoid these common defaults** (they make a design look generated):
- A warm cream background with a serif display face and a terracotta accent, or a near-black background with one acid accent.
- Every item as the same rounded card with the same soft shadow. Use dense rows and lists for folders, devices and files.
- An all-caps tracked label above every heading, numbered markers on non-sequences, monospace for small labels, arrows appended to buttons, a gradient wash as decoration.
- Emphasizing one word in a headline with a different colour or italic.
- Scattered entrance animation and hover effects on every element.
- A pulsing "radar" for nearby devices.

### 8.2 Tokens (`design/tokens.json` is the source; generate platform code from it)

**Colour (light).** Contrast ratios below are approximate. **Re-verify with a contrast checker** and adjust before shipping.

| Token | Value | Use | Text on `color-ground` |
|-------|-------|-----|------------------------|
| `color-ground` | `#E8ECEF` | App background | n/a |
| `color-surface` | `#F6F8F9` | Raised panels, sheets | n/a |
| `color-border` | `#C5CED4` | Dividers that carry meaning | graphic only |
| `color-text` | `#1E3A4F` | Body and headings | about 9 to 1, passes |
| `color-link-direct` | `#2358D6` | Direct link line, primary action | about 5.1 to 1, passes |
| `color-link-relay` | `#B97A0B` | Relay line (**graphic only**, about 3 to 1) | fails for text |
| `color-link-relay-text` | `#8A5A00` | Any amber **text** | about 5 to 1, passes |
| `color-ok` | `#2F6B47` | In sync | about 5.3 to 1, passes |
| `color-danger` | `#A93A48` | Conflicts, destructive actions | about 5.2 to 1, passes |

**Colour (dark).** Derive from the same names: ground `#12202B`, surface `#1B2B38`, text `#E6EDF2`, direct `#7FA3FF`, relay `#E0A93B`, ok `#6FC08D`, danger `#E88A95`. Verify every pair.

**Type.** Headings: Familjen Grotesk. Body and UI: Atkinson Hyperlegible Next. Use tabular figures for speeds and sizes (no monospace face). `VERIFY` licences (both are expected to be open fonts) and bundle the font files in the app. Always set a system-font fallback stack.

| Token | Size / line height | Weight | Use |
|-------|--------------------|--------|-----|
| `text-xs` | 12 / 16 | 400 | Secondary metadata |
| `text-sm` | 14 / 20 | 400 | Rows, helper text |
| `text-md` | 16 / 24 | 400 | Body |
| `text-lg` | 19 / 26 | 500 | Section titles |
| `text-xl` | 23 / 30 | 700 | Screen titles |
| `text-2xl` | 28 / 34 | 700 | First-run headline |

Line length under 80 characters. Sentence case everywhere.

**Spacing (4-point base).** `space-1` 4, `space-2` 8, `space-3` 12, `space-4` 16, `space-5` 24, `space-6` 32, `space-7` 48.

**Radius (by role, not one value everywhere).** `radius-control` 4 for buttons and inputs, `radius-panel` 10 for sheets and dialogs, `radius-pill` 999 for status dots only.

**Elevation.** None by default (use borders). One level for menus and dialogs.

**Motion.** `duration-fast` 120 ms, `duration-base` 200 ms, easing `cubic-bezier(0.2, 0, 0, 1)`. Motion only answers an action (expand, confirm, a file arriving). The only non-triggered motion allowed is a subtle progress on an active transfer. **Respect the OS reduced-motion setting everywhere** and replace motion with a static state.

**Hit targets.** At least 48 dp on Android and 32 px (with a larger hit area) on desktop. Visible keyboard focus ring on every interactive element using `color-link-direct` plus a 2 px offset.

### 8.3 Components (document each with variants, states, props, accessibility, do and don't)

Every component must ship **all** of these states where they apply: default, hover, pressed, focus, disabled, loading, error.

| Component | Variants | Special states and notes |
|-----------|----------|--------------------------|
| **LinkLine** (signature) | direct-local, direct-internet, relayed, connecting, offline | Always paired with a text label. Reduced-motion: no animation. Announced to screen readers as text (Section 10). |
| **DeviceRow** | this-device, remote | Shows name, link state, sync state, last seen. Long names truncate in the middle, full name in a tooltip or long-press. |
| **FolderRow** | send-receive, send-only, receive-only | Shows path, size, device count, state (up to date, syncing, paused, conflicts, error). Dense list row, not a card. |
| **TransferRow** | sending, receiving, queued, paused, failed, done | Progress, speed (tabular figures), time left, interface used. Failed state includes the reason and a fix action. |
| **PairingPanel** | show-code, scan-code, confirm-match | QR plus a short code. Confirm state names both devices. |
| **PermissionSheet** | per permission | Explains **why** before the system dialog. Denied state shows how to fix it in settings. |
| **Banner** | info, warning, error | Inline, persistent until resolved. One action max. Used for firewall, local network, battery, low disk. |
| **ConfirmDialog** | destructive, neutral | Button labels are the actions (Section 9). Destructive default focus is the safe option. |
| **EmptyState** | folders, devices, send, trash | What this is, why it is empty, how to start (one action). |
| **ConflictItem** | file, name-collision, reserved-name | Shows both versions and the action. |
| **Toggle, Button, TextField, Select, Toast** | standard | Button variants: primary, secondary, quiet, destructive. Sizes: md, lg. |

### 8.4 Audit (run before every phase closes and before release)

Produce `design/AUDIT.md` using the design-system audit format:

- **Naming consistency:** components and tokens follow the names above.
- **Token coverage:** count hard-coded colours, spacing values and font sizes outside tokens (target: zero).
- **Component completeness:** states, variants and docs for each component, scored.
- **Priority actions:** top three fixes.

### 8.5 Self-critique loop (every screen, before it counts as done)

1. Take screenshots at desktop and mobile widths, light and dark.
2. Review: first impression (what draws the eye, is it the folder and link line?), usability, hierarchy, consistency, accessibility (contrast, targets, readability).
3. Remove one decoration. Fix the top three findings. Record the critique in `design/CRITIQUE.md`.

---

## 9. UX copy

Source skill: ux-copy.

### 9.1 Voice

Calm, plain and specific. Sentence case. Active voice. No jargon in the main UI. Same word for the same thing everywhere. Errors do not apologize and are never vague. Success is warm but short. Do not use exclamation marks.

### 9.2 Glossary (use these exact terms)

| Use | Do not use in the UI | Notes |
|-----|----------------------|-------|
| Device | peer, node, client | |
| Folder | share, repo, sync root | |
| Send | transfer, push | One-off. |
| Sync | mirror | Continuous. |
| Pair | add device ID, handshake | |
| Pairing code | device ID | Show the long ID only in Advanced. |
| Direct | P2P, peer-to-peer | |
| Relay (slower) | TURN, proxy | |
| Trash | recycle, versions | |
| Conflict | merge issue | Plain explanation in the message. |

### 9.3 Patterns

- **Buttons:** start with a verb and say what happens: "Pair device", "Choose folder", "Send files", "Stop syncing". Never "OK", "Submit", "Yes".
- **Errors:** what happened, why, how to fix.
- **Empty states:** what this is, why it is empty, how to start.
- **Confirmations:** name the action and the consequence. Label buttons with the actions.
- **Permissions:** explain why **before** the system dialog, in one sentence.
- **Loading and progress:** set expectations with real numbers.

### 9.3.1 Copy deck (starter; put in the localizable string file; keys in brackets)

| Key | Copy |
|-----|------|
| `send.empty` | Nothing to send yet. Choose files or a folder, then pick a nearby device. |
| `folders.empty` | No synced folders yet. Choose a folder to keep the same on all your devices. |
| `devices.empty` | No devices yet. Pair a second device to start sending and syncing. |
| `trash.empty` | The trash is empty. Deleted and replaced files stay here for 30 days. |
| `pair.title` | Pair with another device |
| `pair.instruction` | Scan this code on your other device. Both devices must confirm. |
| `pair.confirm` | Does your other device show the code {code}? |
| `pair.success` | Paired with {device}. |
| `link.direct_local` | Direct, same network |
| `link.direct_internet` | Direct, over the internet |
| `link.relayed` | Through a relay (slower) |
| `link.offline` | Not reachable |
| `link.relayed.help` | This device is connected through a relay. Transfers are encrypted but slower. Set up your own relay for better speed. |
| `send.progress` | Sending {done} of {total} files, {speed}, about {time} left. |
| `send.done` | Sent {count} files to {device}. |
| `delete.confirm.title` | Delete {count} files from all devices? |
| `delete.confirm.body` | The files move to the trash on each device and stay there for 30 days. |
| `delete.confirm.yes` / `.no` | Delete files / Keep files |
| `stop.confirm.title` | Stop syncing "{folder}" on this device? |
| `stop.confirm.body` | Files already here stay. New changes will not sync. |
| `stop.confirm.yes` / `.no` | Stop syncing / Keep syncing |
| `perm.background.why` | Allow Tandem to keep running in the background? This lets your folders sync while the screen is off. You can change this later. |
| `perm.background.yes` / `.no` | Allow background sync / Not now |
| `err.discovery_blocked` | Can't see {device}. This network may stop devices from finding each other. Make a hotspot on one device and connect the other to it. |
| `err.discovery_blocked.action` | Make a hotspot |
| `err.firewall_windows` | Windows is blocking Tandem on this network. Allow Tandem so other devices can connect. |
| `err.firewall_windows.action` | Allow Tandem |
| `err.mac_local_network` | Tandem can't see nearby devices. Allow Local Network access in System Settings, Privacy & Security, Local Network. |
| `err.mac_local_network.action` | Open System Settings |
| `err.linux_firewall` | Your firewall is blocking Tandem. Run this command to allow it: {command} |
| `err.disk_full` | Not enough space for "{folder}". It needs {needed} and {free} is free. Free up space, or stop syncing this folder on this device. |
| `err.inotify_limit` | Tandem can't watch every file in "{folder}", so it will check for changes every {interval}. Raise the file-watch limit to get instant updates. |
| `conflict.both_changed` | Both devices changed "{file}". Tandem kept both. Open "{copy}" to compare. |
| `conflict.case` | "{a}" and "{b}" can't both exist on Windows or macOS. Rename one to sync both. |
| `conflict.reserved` | "{file}" can't be created on Windows. Rename it to sync it to your Windows devices. |
| `status.no_internet` | No internet. Devices on this network can still find each other and sync. |

### 9.4 Localization notes

Allow 40% text expansion. No concatenated strings (use whole sentences with placeholders). Use plural-aware message formats. Avoid idioms. Support right-to-left layouts. Do not embed text in images. Date, time, size and speed formats follow the user's locale.

---

## 10. Design handoff

Source skill: design-handoff. For every screen, write a spec in `design/handoff/<screen>.md` using the skill's format: Overview, Layout, Design Tokens Used (token names, never raw values), Components, States and Interactions, Responsive Behavior, Edge Cases, Animation / Motion, Accessibility Notes.

Principles: do not assume (if it is not specified, a developer will guess), use tokens not values, show all states, explain the why.

### 10.1 Screens to specify

| ID | Screen | Notes |
|----|--------|-------|
| S1 | First run | Explain Send vs Sync in two short lines. One action: pair the first device. |
| S2 | Folders | List of FolderRow. Empty state. Add folder. |
| S3 | Folder detail | Files, devices sharing it, conflicts, trash, folder type. |
| S4 | Send | Pick files, pick a nearby device, progress. |
| S5 | Devices | List of DeviceRow with LinkLine. |
| S6 | Device detail and link status | Link state, per-interface info, speed history, relay info, Advanced (long ID). |
| S7 | Pairing | PairingPanel: show, scan, confirm. |
| S8 | No-internet helper | Flows B to E (Section 5.3) as guided steps with QR codes. |
| S9 | Health check | Firewall, Local Network permission, battery, storage, discovery self-test, each with a fix action. |
| S10 | Settings | Network limits, Wi-Fi only, metered networks, relay, "Hide from this network", trash retention, startup. |
| S11 | Activity | Recent transfers and errors. |

### 10.2 Required responsive behaviour

| Breakpoint | Layout |
|------------|--------|
| Desktop (over 1024 px) | Two panes: device list left, content right. The link line is drawn between this device and the selected device. |
| Tablet (768 to 1024 px) | Collapsible device pane. |
| Mobile (under 768 px) | Bottom navigation with Folders, Send, Devices. Settings in the header. Link status is a sheet from the device row. One-handed reach for primary actions. |

### 10.3 Required edge cases in every relevant spec

Empty, loading, error, offline, very long file and device names, 100,000 files in a folder, 50 devices, slow connection, a device that is paired but has been offline for months, low disk, system language with longer strings, right-to-left.

### 10.4 Accessibility requirements

- Logical focus order. All actions reachable by keyboard on desktop.
- A device's state is announced as one sentence, for example: "Maya's phone, direct, same network, syncing, 12 files remaining."
- Progress updates are announced politely and not on every tick.
- Dialogs trap focus and return it on close. Escape closes non-destructive dialogs.
- Never rely on colour alone (always line style plus text).
- Respect OS text scaling up to 200% without clipping.

---

## 11. Testing and research

### 11.1 Compatibility matrix (automate what you can; record manual results)

Test every OS pair that you can access. Include same-OS pairs.

| From \ To | Windows | macOS | Linux | Android |
|-----------|---------|-------|-------|---------|
| Windows | yes | yes | yes | yes |
| macOS | yes | yes | yes | yes |
| Linux | yes | yes | yes | yes |
| Android | yes | yes | yes | yes |

For each pair, run these scenarios:

1. Same Wi-Fi with internet.
2. Same Wi-Fi with the WAN unplugged (no internet).
3. Phone hotspot with mobile data off.
4. Guest Wi-Fi with client isolation (expect Flow E guidance).
5. Different networks, both behind ordinary NAT (direct over the internet).
6. A hard NAT that forces a relay, then a switch to direct.
7. Network changes mid-transfer (Wi-Fi to Ethernet, Wi-Fi to hotspot).
8. Sleep and wake on each side mid-transfer.
9. One 10 GB file, then 100,000 small files, then a 10,000-photo folder.
10. Names with accents, emoji, very long paths, case-only differences, Windows reserved names.
11. Disk full on the receiver.
12. Delete on one device and recover from the trash on another.
13. Two devices edit one file at the same time (conflict).

Record speed, time to first byte and success for each in `docs/MEASUREMENTS.md`.

### 11.2 Usability research (before Phase 4 closes and before release)

Run a usability test with 5 to 8 participants who move files between a phone and a computer, including at least some who use two different OS. Tasks: pair two devices, send 20 photos to a laptop with no internet, set up a synced folder, recover a deleted file, and fix a "can't see device" problem. Measure time, errors and where people hesitate. Key questions: do people understand Send versus Sync, do they expect full copies or on-demand files (feeds D1), and do they understand the link line. Write findings (themes, quotes, recommendations) to `docs/RESEARCH.md` and fix the top three issues.

---

## 12. Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Android background and storage limits, and store policy | Sync stops or cannot read photos | Phase 2 decisions D4 and D5, test on several brands, document gaps per distribution channel |
| macOS Local Network permission denied | Discovery silently fails | Self-test, plain-language fix screen |
| Windows hotspot may need an internet connection | No laptop-as-hotspot flow | `VERIFY` in Phase 1, otherwise guide user to a phone hotspot |
| Router-less links between OS | Some pairs impossible | Label unsupported pairs clearly, ship only tested ones |
| Relay speed | Far-away sync slower than hoped | Honest UI, self-hosted relay, measurements |
| Syncthing internals are not a stable library API | Upgrades break the build | Pin versions, wrap behind `core/engine`, prefer the REST API for v1 |
| Data loss from sync (deletes, conflicts, bugs) | Severe | Trash and versioning, atomic writes, chaos tests, no silent deletes |
| Licence mistakes | Legal | Section 2.3 audit |
| Cross-OS file name differences | Files fail to sync or collide | Section 4.7 and tests |

---

## 13. Definition of done

The project is done for a release when **all** are true:

- [ ] Every phase "Done when" list is met, or exceptions are listed in `docs/PLATFORM_STATUS.md` with reasons.
- [ ] The Section 11.1 matrix has been run, with results recorded.
- [ ] A fresh install works on Windows, macOS, Linux and Android with no developer tools.
- [ ] Send works with **no internet** on each supported OS pair, and the app says clearly which pairs are unsupported.
- [ ] Far-away sync works directly when NAT allows, and shows relay use honestly otherwise.
- [ ] No user file is deleted without a recoverable copy.
- [ ] Design audit shows zero hard-coded values outside tokens. All screens have handoff specs. Accessibility checks pass.
- [ ] All user-facing strings are in the copy deck and follow the glossary.
- [ ] Licence notices are complete. Signed builds are produced for Windows and macOS.

**When you are stuck:** stop, write what you tried and what you expected in `docs/DECISIONS.md`, list two or three options with a recommendation, and ask the human. Do not work around a safety rule in this guide to make progress.
