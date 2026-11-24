# Decisions and Verification Log

This document records architectural decisions, `VERIFY` resolutions against upstream sources and operating system specifications, and pending decision gates as mandated by Section 0 of the Tandem Agent Guide.

---

## 1. Resolved Verifications (`VERIFY` Findings)

### V1. Syncthing Version, Ports, and Library Safety (Sections 2.1 & 4.2)
- **Current Stable Version:** Syncthing v1.29.x / v2.1.x.
- **Default Ports:**
  - TCP 22000: Data sync (BEP)
  - UDP 22000: Data sync (QUIC / BEP)
  - UDP 21027: Local discovery announcements (IPv4 broadcast & IPv6 multicast)
  - TCP 22067: Relay protocol
- **Go `lib/` Package Import Stability:**
  - *Finding:* Syncthing maintainers explicitly do not guarantee API stability for packages in `lib/`. Internal packages and types frequently change between releases.
  - *Resolution:* Do not tightly link internal Go packages from `github.com/syncthing/syncthing/lib/...` into Tandem's core domain. Run the engine headless and control it via its stable localhost REST API and streaming Event API, or wrap the process lifecycle cleanly behind `core/engine`.
- **Parallel Connections per Device Pair:**
  - *Finding:* Syncthing supports the `numConnections` setting on remote devices. When configured on both ends (where `numConnections > 1`), Syncthing dedicates one connection exclusively to metadata (index updates) and randomly distributes data block transfers across the remaining parallel connections (up to 128).
  - *Resolution:* This natively supports Phase 7 multipath block scheduling over multiple interfaces when combined with per-interface socket binding.

### V2. Socket Binding per Operating System (Section 4.2)
- **Linux:** Non-privileged processes can bind sockets to specific local IP addresses before connecting. `SO_BINDTODEVICE` requires `CAP_NET_RAW` or root on older kernels, so IP-based local binding (`net.Dialer.LocalAddr`) is the portable, safe default.
- **Windows:** Bind the local socket to the adapter's IP address prior to connect, or configure `IP_UNICAST_IF` / `WSAIoctl(SIO_ROUTING_INTERFACE_QUERY)`.
- **macOS / iOS:** Sockets bind to interfaces via `IP_BOUND_IF` / `IPV6_BOUND_IF` socket options.
- **Android:** Android `ConnectivityManager` provides `Network` objects. Sockets are explicitly bound to the network via `Network.bindSocket(socket)`.

### V3. Windows Hotspot Without Internet Connection (Sections 4.3 & 12)
- **Investigation:** WinRT `NetworkOperatorTetheringManager` was evaluated for ad-hoc Wi-Fi hotspot creation without internet.
- **Finding:** Windows `NetworkOperatorTetheringManager.CreateFromConnectionProfile()` requires an active internet connection profile (`GetInternetConnectionProfile()`). When internet is absent, it returns `null` or errors out, unless artificial loopback adapters are installed via device manager.
- **Resolution:** As specified in Section 4.3, mark `Hotspot.Create` as unsupported on Windows. Guide Windows users to connect to a phone's local hotspot (Flow B) instead.

### V4. macOS Process Model & Local Network Permissions (Section 4.4)
- **Process Model:** `SMAppService` is standard on macOS 13 (Ventura) and newer for managing background agents. The daemon binary must reside inside `Contents/MacOS` or `Contents/Helpers` of the signed `.app` bundle.
- **Local Network Privacy:** macOS 15 (Sequoia) introduced strict Local Network Privacy matching iOS.
  - *Requirement:* `NSLocalNetworkUsageDescription` must be included in `Info.plist`.
  - *Finding:* If missing, macOS silently blocks local UDP/TCP broadcast and discovery without prompting the user.
  - *Resolution:* Bundle `NSLocalNetworkUsageDescription` with clear explanation. Implement discovery self-test; if packets drop, display actionable link to `System Settings > Privacy & Security > Local Network`.

### V5. Linux Hotspot Support & inotify Limits (Section 4.5)
- **Hotspot:** `nmcli device wifi hotspot` functions only if the Wi-Fi card supports AP mode (`iw list` contains `AP` under `Supported interface modes`). PAL checks `iw list` before advertising hotspot creation.
- **Storage inotify Limits:** `fs.inotify.max_user_watches` defaults on Linux distributions (often 8192 or 65536) can be exhausted by large directory trees. When watches fail, Tandem will fall back to periodic interval scans and display Banner `err.inotify_limit` with the `sysctl` command.

### V6. Android Foreground Service Types and Timeouts (Section 4.6)
- **Finding:** In Android 14+, `android:foregroundServiceType="dataSync"` requires `FOREGROUND_SERVICE_DATA_SYNC`. Android 15 (API 35) introduced a strict 6-hour cumulative limit in a 24-hour window for `dataSync` services, triggering `onTimeout()` and killing the process if not stopped promptly.
- **Resolution:** Active synchronization should be driven by foreground UI presence or bounded transfers with high-priority wake locks and Wi-Fi locks only during active transfers. For long background sync, battery-optimization exemption is requested with user consent.

---

## 2. Decision Gates

### DECISION D3 (Phase 0): UI Toolkit Selection
- **Status:** PENDING HUMAN DECISION
- **Options:**
  - **Option 1 (Recommended): Flutter (Single Cross-Platform Codebase)**
    - *Pros:* Single codebase across Windows, macOS, Linux, and Android. Direct support for custom layout, canvas rendering for signature `LinkLine`, theme tokens, and unified localization deck.
    - *Cons:* Binary size is slightly larger; requires Flutter SDK.
  - **Option 2: Tauri (Desktop: Windows/macOS/Linux) + Kotlin/Jetpack Compose (Android)**
    - *Pros:* Native Android look and feel; small web-view footprint on desktop.
    - *Cons:* Two independent UI codebases to build, maintain, audit for design tokens, and localize. Double the testing and development surface.
- **Recommendation:** Option 1 (Flutter) as outlined in Section 3.1 and 7 (Phase 0).

---

## 3. Future Decision Gates Reference
- **DECISION D1 (before Phase 4):** Full copy vs. on-demand file placeholders.
- **DECISION D2 (before Phase 4):** Send design: ephemeral single-recipient folder over BEP vs. separate HTTPS transfer protocol.
- **DECISION D4 (Phase 2):** Android background policy (sync on Wi-Fi/charging vs. always-on).
- **DECISION D5 (Phase 2):** Android storage model and distribution channel (All-files access for direct/F-Droid vs. SAF/MediaStore for Google Play).
