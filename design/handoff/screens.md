# Design Handoff Specifications: Screens S1 to S11

In accordance with Section 10 of the Tandem Agent Guide, this document provides the engineering handoff specifications for all eleven primary screens. All visual references use design token names; no raw values are permitted.

---

## Screen S1: First Run

- **Overview:** Introduces Tandem in two concise lines, explaining Send vs. Sync. Directs the user to pair their first device.
- **Layout:** Centered single-column layout on `color-ground`. Max width 480px.
- **Tokens Used:** `color-ground`, `color-surface`, `color-text`, `color-link-direct`, `text-2xl`, `text-md`, `space-5`, `space-6`, `radius-panel`.
- **Components:** `EmptyState`, `TandemButton` (size: lg, variant: primary).
- **Responsive Behavior:**
  - Desktop / Tablet / Mobile: Identical centered layout. One primary button: `"Pair device"`.
- **Edge Cases:** Screen-reader users hear Send vs. Sync distinction immediately upon landing.
- **Accessibility:** Default focus on `"Pair device"`.

---

## Screen S2: Folders (Main Sync View)

- **Overview:** Displays user's synced folders, total data size, and sync states.
- **Layout:** Dense row list on `color-surface`. Header displays view title and `"Add folder"` action.
- **Tokens Used:** `color-surface`, `color-border`, `color-text`, `color-ok`, `color-danger`, `text-xl`, `text-md`, `text-xs`, `space-4`, `space-2`.
- **Components:** `FolderRow`, `TandemButton` (variant: primary), `EmptyState` (`folders.empty`).
- **Responsive Behavior:**
  - Desktop (>1024px): Right pane in two-pane view.
  - Tablet (768-1024px): Full-width pane.
  - Mobile (<768px): Primary tab in bottom navigation. Floating or top-right `"Add folder"` action.
- **Edge Cases:** 100,000 files in folder: UI uses virtualized ListView, never blocks UI thread.

---

## Screen S3: Folder Detail

- **Overview:** Shows file tree, sharing peers, conflict warnings, trash management, and folder mode (Send & Receive, Send-only, Receive-only).
- **Tokens Used:** `color-surface`, `color-border`, `color-link-direct`, `color-danger`, `text-lg`, `text-sm`, `space-3`, `space-4`.
- **Components:** `BannerNotification` (conflicts), `TandemButton` (pause/resume), `ConfirmDialog` (`stop.confirm`).
- **Edge Cases:** Low disk space: Displays persistent error banner (`err.disk_full`).

---

## Screen S4: Send (One-Off Transfer)

- **Overview:** Direct, ephemeral file transfer (Section 1 & DECISION D2). Pick files, pick nearby device, send now.
- **Tokens Used:** `color-ground`, `color-surface`, `color-link-direct`, `text-xl`, `text-md`, `space-4`, `space-5`.
- **Components:** `DeviceRow`, `TransferRow`, `EmptyState` (`send.empty`).
- **States:** Idle, Transferring (live tabular figures for speed and remaining time), Complete.

---

## Screen S5: Devices

- **Overview:** Lists this device and all paired and discovered peers.
- **Layout:** Dense vertical list of `DeviceRow` components with signature `LinkLine` indicators.
- **Tokens Used:** `color-ground`, `color-surface`, `color-border`, `color-link-direct`, `color-link-relay`, `text-xl`, `text-sm`.
- **Responsive Behavior:**
  - Desktop (>1024px): Left navigation pane (fixed width 320px). Selected device shows `LinkLine` connecting to right pane.
  - Mobile (<768px): Tab in bottom navigation.

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
