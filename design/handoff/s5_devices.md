# Screen S5: Devices

## 1. Overview
The Devices screen inventories all trusted peers and newly discovered local devices. It serves as the primary visual display for connection topology, featuring Tandem's signature `LinkLine` indicator showing whether links are direct local, direct internet, or relayed.

## 2. Layout
- **Header:** Title ("Devices"), local device identity card ("This device: [Name]"), and "Pair new device" action button.
- **List Sections:**
  1. This Device (always pinned to top)
  2. Paired Devices (active and offline)
  3. Nearby Unpaired Devices (discovered via UDP / Wi-Fi Direct)

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-link-direct`, `color-link-relay`, `color-link-relay-text`
- **Typography:** `font-sans`, `font-mono` (short device ID, IP addresses), `text-xl`, `text-md`, `text-sm`, `text-xs`
- **Spacing:** `space-2`, `space-3`, `space-4`, `space-5`
- **Border Radius:** `radius-panel`, `radius-badge`

## 4. Components
- `DeviceRow` (device name, OS icon, `LinkLine`, last seen, action overflow)
- `LinkLine` (custom painter rendering solid green for direct, dashed amber for relay)
- `TandemButton` (variant: primary, icon: qr_code, text: "Pair device")
- `EmptyState` (`devices.empty` when no other devices are paired)

## 5. States and Interactions
- **Direct Link:** Solid green `LinkLine` with subtitle "Direct (same network)".
- **Relayed Link:** Dashed amber `LinkLine` with subtitle "Through a relay (slower)".
- **Offline Device:** Dimmed gray line with subtitle "Offline (last seen 2d ago)".
- **Tap Device:** Navigates to Screen S6 (Device Detail & Link Status).

## 6. Responsive Behavior
- **Desktop (>1024px):** Fixed left navigation pane (320px width). The selected device renders an active indicator linking directly into the right detail pane.
- **Tablet (768px - 1024px):** Collapsible drawer.
- **Mobile (<768px):** Dedicated tab in bottom navigation bar.

## 7. Edge Cases
- **50+ Devices:** Virtualized scroll container ensuring 60fps scrolling.
- **Device Offline for Months:** Clearly separated into an "Inactive" collapsible sub-section to prevent visual clutter.
- **Duplicate Device Names:** Appends short 4-character ID hash (`Pixel 9 Pro [A4F2]`).

## 8. Animation / Motion
- `LinkLine` status transition pulses once on state change (e.g. upgraded from relayed to direct).

## 9. Accessibility Notes
- Each `DeviceRow` announces combined state in a single natural sentence: "Maya's phone, direct, same network, syncing, 12 files remaining."
- Never relies on color alone: dashed stroke style and explicit label accompany relay status.
