# Tandem WS3 Visual Self-Critique (`S1`–`S11`)

Evaluated rendered PNG captures under `design/screenshots/` across `1920x1080`, `1280x800`, and `390x844` in Light and Dark themes against `TANDEM_AGENT_GUIDE.md` Sections 8–10 and `design/PLAN.md`.

---

## Screen-by-Screen Findings & Resolutions

### S1 — `FirstRunScreen` (`empty-1920-light`, `empty-1280-dark`, `empty-390-light`)
1. **Device ID wrapping on 390px:** The 56-character Device ID wrapped mid-group (`...-6666\n666-7777777`) on mobile.
   - *Fix:* Scaled mobile mono font to `11.0px` with `space_1` spacing below the device label.
2. **Dark vs. Light contrast:** Strong hierarchy (`Send` / `Sync` two-row rule table, single primary CTA). Removed decorative eyebrow noise; left-aligned `680px` layout keeps scan lines short.

### S2 — `FoldersScreen` & `HomeShell` (`synced-*`, `failing-*`)
1. **Missing inline health/error banner on home workspace:** In `failing-1280-light` and `failing-390-dark`, `Projects` showed `Sync error` while critical daemon health failures (storage error, blocked firewall, discovery unavailable) were invisible until opening Health Check.
   - *Fix:* Added persistent `BannerNotification` at the top of `FoldersScreen` when `SystemHealth` reports active faults, with a single `"Health Check"` action.
2. **Mobile bottom bar shadow & path truncation:** On `390x844`, `BottomNavigationBar` rendered an unexpected dark elevation edge, and `/home/user/Pictures/Camera` truncated at the trailing edge (`Came...`).
   - *Fix:* Replaced `BottomNavigationBar` elevation with a `0.5px` top hairline border, added a `0.5px` bottom hairline on mobile `AppBar`, and tightened middle-truncation threshold in `FolderRow` (`maxLen: 20`) so leaf folder names remain legible.
3. **Desktop rail peer dot mismatch:** Relayed peer `node-gamma-phone` showed a green/blue dot despite its amber dotted `LinkLine`, and unpaired nearby devices showed an active green `"up to date"` dot.
   - *Fix:* `DeviceRow` now maps `relayed` -> `t.linkRelay`, `offline`/`connecting` -> `t.border`, and `DeviceSyncState.offline` (unpaired/idle nearby) -> `t.border`.

### S3 — `FolderDetailScreen` (`folder-detail-error-1280-light`)
1. **`RadioListTile` Material exception & DEBUG banner:** Wrapping `RadioListTile` inside `Container(color: t.surface)` triggered a Flutter framework exception (`ListTile background color or ink splashes may be invisible`), and standalone capture showed the red `DEBUG` ribbon over `"Pause"`.
   - *Fix:* Replaced `Container` with `Material(color: t.surface)` and disabled debug banner in test harness.
2. **Internal identifiers & grammar in UI copy:** Error banner printed raw `err.disk_full:` prefix, `Shared with` showed raw Device IDs instead of peer names, and trash count read `"1 files"`.
   - *Fix:* Mapped error codes to plain-language descriptions, resolved peer IDs to friendly device names via `TandemController.devices`, fixed singular/plural `"1 file"`, and added `embedded: true` support so desktop keeps the navigation rail visible.

### S4 — `SendScreen` (`send-1280-light`)
1. **Internal session ID in transfer row:** Active transfer row displayed `snd-001 (3/5 files)` instead of recipient name.
   - *Fix:* Formatted transfer rows as `"3 of 5 files to node-beta-laptop"`.
2. **Unstyled Material underline inputs:** Recipient dropdown and file path input used raw bottom underlines inside the rounded panel.
   - *Fix:* Styled form controls with `OutlineInputBorder` (`radius_control`, `0.5px` `t.border`, `t.ground` fill).

### S5 — `DevicesScreen` (`devices-1280-light`)
1. **Header button clustering:** `Devices`, `"Offline transfer guide"`, and `"Pair device"` clustered on the left via `Wrap` instead of aligning actions to the right edge like `Folders`, `Health Check`, and `Settings`.
   - *Fix:* Switched header to `Row` with `Expanded` title and right-aligned action group (`Wrap`).
2. **Unpaired nearby peer dot:** Discovered unpaired peer `studio-desktop` rendered a green status dot (`t.ok`).
   - *Fix:* `DeviceRow` renders neutral border dot for `DeviceSyncState.offline` (nearby unpaired).

### S6 — `LinkStatusScreen` (`link-status-relayed-1280-light`)
1. **Casing consistency:** `Firewall` displayed lowercase `open` alongside title-cased `Ready`, `Listening`, and `Active`.
   - *Fix:* Capitalized diagnostic state labels (`Open`, `Blocked`, `Unknown`).

### S7 — `PairingScreen` & `PairingPanel` (`pairing-1280-light`, `pairing-390-light`)
1. **Blank pairing code & URI in screenshot capture:** Mock server intercepted `/pair/code` instead of `ApiClient.getPairingCode()`'s `/pairing/code`, leaving `shortCode` and `qrPayload` empty in the panel.
   - *Fix:* Updated test mocks in `screenshots_ws3_test.dart` and `screens_empty_state_test.dart` to `/pairing/code`, added safe non-empty fallback in `PairingPanel`, and styled right-hand inputs with `OutlineInputBorder`.

### S8 — `NoInternetHelperScreen` (`no-internet-1280-light`)
1. **Clean flow switcher & zero clutter:** Single info banner, flat radio rows with `0.5px` rules, and focused step card. No blocking defects found; verified light/dark token coverage.

### S9 — `HealthCheckScreen` (`health-failing-1280-light`)
1. **Hidden firewall remediation command:** When `firewallRemediation` was present, `firewallCommand` (`sudo ufw allow 22000 && sudo ufw allow 21027/udp`) was omitted.
   - *Fix:* Joined both `firewallRemediation` and `firewallCommand` in the selectable monospace help block and title-cased `firewallState`.

### S10 — `SettingsScreen` (`settings-1280-dark`)
1. **Casing consistency & dark-mode legibility:** Dark mode (`#12202B` / `#1B2B38` / `#E6EDF2`) and tabular port numbers align cleanly; title-cased `Daemon state` (`Running`, `Degraded`, `Idle`).

### S11 — `ActivityScreen` (`activity-1280-light`)
1. **Raw device ID & `(s)` pluralization:** Displayed `5 file(s) to NODEB-...` when `targetDeviceId` was a Device ID.
   - *Fix:* Resolved friendly peer name via `controller.devices` and used proper singular/plural (`"5 files to node-beta-laptop"`).
