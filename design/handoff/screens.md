# Design Handoff Specifications: Screens S1 to S11

In accordance with Section 10 of the Tandem Agent Guide, this document provides the engineering handoff specifications for all eleven primary screens. All visual references use design token names; no raw values are permitted.

---

## Screen S1: First Run

- **Overview:** Introduces Tandem in two concise lines, explaining Send vs. Sync, plus real local device identity (`myDeviceName`, `myDeviceId`). Directs the user to pair their first device or open System Health Check.
- **Layout:** Left-aligned single-column layout on `color-ground`. Max width 680px (`WorkspacePane`).
- **Tokens Used:** `color-ground`, `color-border`, `color-text`, `color-link-direct`, `text-2xl`, `text-md`, `space-5`, `space-6`.
- **Components:** `TandemButton` (size: lg, variant: primary `"Pair first device"`, secondary `"System health check"`).
- **Responsive Behavior:**
  - Desktop / Tablet / Mobile: Identical left-aligned layout with 0.5px horizontal rules separating `Send` and `Sync` descriptions.
- **Edge Cases:** Screen-reader users hear Send vs. Sync distinction immediately upon landing. Long Device ID wraps cleanly at `11px` on narrow screens.
- **Accessibility:** Default focus on `"Pair first device"`.

---

## Screen S2: Folders (Main Sync View)

- **Overview:** Displays user's synced folders, sync mode, total data size, peer count, and sync states, plus persistent `BannerNotification` warnings when `SystemHealth` reports faults.
- **Layout:** Left-aligned workspace (`maxWidth: 960px`) with column-aligned table header on `>= 768px` and dense `FolderRow` list on `color-surface` separated by `0.5px` `color-border` dividers.
- **Tokens Used:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-ok`, `color-danger`, `text-xl`, `text-md`, `text-xs`, `space-4`, `space-2`.
- **Components:** `FolderRow`, `BannerNotification`, `TandemButton` (variant: primary `"Choose folder"`), `EmptyState` (`folders.empty`).
- **Responsive Behavior:**
  - Desktop (>=1024px): Right workspace (`maxWidth: 960px`) beside persistent `288px` left navigation + live `Peers` rail.
  - Tablet (768-1024px): Full-width scrollable pane with table columns.
  - Mobile (<768px): Primary tab in bottom navigation (`0.5px` top hairline, `elevation: 0`). Compact two-line `FolderRow` with middle-truncated path.
- **Edge Cases:** 100,000 files in folder: UI uses virtualized ListView, never blocks UI thread.

---

## Screen S3: Folder Detail

- **Overview:** Shows folder path, file count, size, resolved peer names, conflict/disk-full banners, folder mode picker (`Send & Receive`, `Send only`, `Receive only`), `.tandem-trash` recovery list, and `"Stop syncing folder"`.
- **Tokens Used:** `color-ground`, `color-surface`, `color-border`, `color-link-direct`, `color-danger`, `text-lg`, `text-sm`, `space-3`, `space-4`.
- **Components:** `BannerNotification`, `TandemButton` (Pause/Resume, Restore, Stop syncing), `ConfirmDialog` (`confirm.stop_syncing`).
- **Responsive Behavior:** Embedded inside the `960px` desktop workspace (preserving the left rail) or pushed as a full screen on mobile.
- **Edge Cases:** Low disk space: Displays persistent plain-language error banner without raw internal error prefixes.

---

## Screen S4: Send (One-Off Transfer)

- **Overview:** Direct, ephemeral file transfer (Section 1 & DECISION D2). Inline composer (recipient dropdown + multi-line file paths) above active/completed `TransferRow` queue.
- **Tokens Used:** `color-ground`, `color-surface`, `color-border`, `color-link-direct`, `text-xl`, `text-md`, `space-4`, `space-5`, `radius-control`, `radius-panel`.
- **Components:** `TransferRow` (friendly peer name, link tag, tabular speed & remaining bytes), `EmptyState` (`send.empty`).
- **States:** Idle, Transferring (live tabular figures for speed and remaining bytes), Complete, Failed.

---

## Screen S5: Devices

- **Overview:** Lists this device, paired devices, and nearby discovered unpaired peers.
- **Layout:** Left-aligned `960px` workspace with right-aligned `"Offline transfer guide"` and `"Pair device"` actions above `DeviceRow` lists with signature `LinkLine` indicators.
- **Tokens Used:** `color-ground`, `color-surface`, `color-border`, `color-link-direct`, `color-link-relay`, `text-xl`, `text-sm`.
- **Responsive Behavior:**
  - Desktop (>=1024px): Left navigation + live `Peers` rail (`288px`) remains persistent; selecting any device opens `LinkStatusScreen` inside the right `960px` workspace.
  - Mobile (<768px): Tab in bottom navigation; selecting a device pushes `LinkStatusScreen`.

---

## Screen S6: Device Detail & Link Status

- **Overview:** Comprehensive connection status, per-interface accounting (Plexo multipath model), speed history, relay disclosure, and Advanced (full Device ID).
- **Tokens Used:** `color-surface`, `color-link-direct`, `color-link-relay`, `color-link-relay-text`, `text-lg`, `text-xs`, `space-4`.
- **Components:** `LinkLine`, `BannerNotification` (`link.relayed.help`), `TandemButton` (`"Unpair device"`).
- **Honest Relay Reporting:** If connection is relayed, explicitly labels `"Through a relay (slower)"` with explanation banner.

---

## Screen S7: Pairing

- **Overview:** Bi-directional pairing handshake with QR code and 6-digit verification code.
- **Tokens Used:** `color-surface`, `color-ground`, `color-link-direct`, `text-2xl`, `text-sm`, `space-5`, `radius-panel`.
- **Components:** `PairingPanel`, `TandemButton`.
- **Accessibility:** 6-digit code announced as individual digits to avoid screen-reader mispronunciation.

---

## Screen S8: No-Internet Helper

- **Overview:** Step-by-step guidance for offline transfer scenarios (Section 5.3, Flows B to E).
- **Flows Covered:**
  - Flow B: Phone creates hotspot; shows Wi-Fi QR code (`WIFI:T:WPA;S:...;P:...;;`) and pairing QR code.
  - Flow C: Laptop creates hotspot (Linux).
  - Flow D: macOS guidance (join phone hotspot).
  - Flow E: Client isolation / discovery blocked guidance.

---

## Screen S9: Health Check

- **Overview:** System diagnostic dashboard displaying firewall state, local network permissions, storage inotify limits, and battery optimization state.
- **Tokens Used:** `color-surface`, `color-ok`, `color-danger`, `text-md`, `text-sm`, `space-3`.
- **Components:** `BannerNotification` with one-click remediation actions.

---

## Screen S10: Settings

- **Overview:** Preferences for network limits, Wi-Fi only transfers, metered connection rules, self-hosted relay configuration, `"Hide from this network"`, trash retention (default: 30 days), and autostart on login.
- **Tokens Used:** `color-surface`, `color-border`, `text-md`, `text-sm`, `space-4`.
- **Components:** `TandemButton`, `ConfirmDialog`.

---

## Screen S11: Activity Log

- **Overview:** Audit trail of recent transfers, completed syncs, recovered trash files, and error notices.
- **Tokens Used:** `color-surface`, `color-text`, `text-sm`, `text-xs`, `space-3`.
- **Components:** `TransferRow`.
