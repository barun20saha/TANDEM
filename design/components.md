# Tandem Design System: Component Catalog & Specifications

This document catalogs every UI component, variants, lifecycle states, accessibility requirements, and do/don't rules in compliance with Section 8.3 of the Tandem Agent Guide.

---

## 1. LinkLine (Signature Element)

- **Purpose:** Visually renders the communication path topology between two devices. The single memorable element of the product (Section 8.1).
- **Variants:**
  - `direct-local`: Solid line (`color-link-direct`). Same LAN, hotspot, or direct cable.
  - `direct-internet`: Dashed line (6px dash, 4px gap). Internet direct connection via NAT hole punching.
  - `relayed`: Dotted line (2px dot, 4px gap) (`color-link-relay`). Through an encrypted relay server.
  - `connecting`: Muted dashed line (`color-border`). Attempting handshake.
  - `offline`: None / transparent. Not reachable.
- **States:**
  - Default: Renders static path line.
  - Reduced-motion: Never pulses or animates.
- **Accessibility:** Always paired with a visible text label. Screen readers announce: `"Connection status: Direct, same network"`, etc. Never conveys state via color alone.
- **Do:** Use prominently between this device and remote peers.
- **Don't:** Add decorative pulsing radar circles or glow animations.

---

## 2. DeviceRow

- **Purpose:** Dense row representing a local or remote paired device.
- **Variants:**
  - `this-device`: Shows local hostname and `"This device"` badge.
  - `remote`: Shows remote device name, LinkLine status, sync state, and last-seen timestamp.
- **States:** Default, Hover, Pressed, Focus, Disabled.
- **Edge Cases:** Long device names truncate in the middle (e.g., `Barun’s Work Lapt...Special Edition`), preserving the beginning and end.
- **Accessibility:** Minimum touch target height 48dp on mobile, 32px on desktop. Logical keyboard tab order.
- **Do:** Keep list dense and scannable.
- **Don't:** Render as a floating card with drop shadow.

---

## 3. FolderRow

- **Purpose:** Dense row representing a synchronized directory.
- **Variants:**
  - `sendreceive`: Standard bidirectional mirror.
  - `sendonly`: Local changes propagate outbound; remote modifications ignored.
  - `receiveonly`: Remote changes received; local modifications protected.
- **States:**
  - `up-to-date`: Green status text (`color-ok`).
  - `syncing`: Direct blue status text (`color-link-direct`).
  - `paused`: Neutral muted text.
  - `conflicts` / `error`: Danger crimson text (`color-danger`).
- **Accessibility:** Full screen reader announcement of path, folder type, sync state, size, and device count.
- **Do:** Show absolute path and formatted size using tabular figures.
- **Don't:** Use rounded card grids for folder listings.

---

## 4. TransferRow

- **Purpose:** Real-time transfer progress row for active Send or Sync sessions.
- **Variants:** `sending`, `receiving`, `queued`, `paused`, `failed`, `done`.
- **States:**
  - Default / In-progress: Displays linear progress bar, speed (in tabular figures, e.g., `24.5 MB/s`), remaining time, and active physical interface (`Wi-Fi`, `Hotspot`, `Relay`).
  - Failed: Explains failure cause with one-click `"Retry transfer"` action.
- **Accessibility:** Politeness `polite` on live region updates; avoids tick-by-tick audio spam.
- **Do:** Always display the network interface carrying the blocks.
- **Don't:** Use estimated time without real rate measurement.

---

## 5. PairingPanel

- **Purpose:** Bi-directional pairing handshake interface (Section 6).
- **Variants:** `show-code`, `scan-code`, `confirm-match`.
- **Elements:**
  - QR Code encoding: `tandem://pair?id=<deviceId>&name=<name>&hint=<addr>&n=<nonce>`
  - 6-digit verification code (e.g., `849-210`) in tabular figures.
- **States:**
  - Code Match: Presents `"Does your other device show the code {code}?"` with `"Confirm match"` and `"Codes do not match"` buttons.
- **Do:** Require explicit user confirmation on both devices.
- **Don't:** Auto-pair unknown devices without confirmation.

---

## 6. BannerNotification

- **Purpose:** Inline, persistent system state or diagnostic warning.
- **Variants:** `info`, `warning`, `error`.
- **Constraints:** At most one action button. Persistent until the underlying condition is remediated (e.g., firewall rule added).
- **Do:** State what happened and offer an exact fix (e.g., `"Allow Tandem in Windows Security"`).
- **Don't:** Show vague dismissible toasts for critical blocks.

---

## 7. ConfirmDialog

- **Purpose:** Explicit user consent for destructive or disruptive operations.
- **Variants:** `destructive` (e.g., deleting synced files), `neutral` (stopping folder sync).
- **Interaction Rules:**
  - Buttons are labeled with verbs (e.g., `"Delete files"` / `"Keep files"`), never `"OK"` / `"Cancel"`.
  - On destructive dialogs, default focus is placed on the safe action (`"Keep files"`).
  - Traps keyboard focus; closes on Escape key.

---

## 8. EmptyState

- **Purpose:** Helpful guidance when a view has no items.
- **Variants:** `folders`, `devices`, `send`, `trash`.
- **Pattern:** Three lines: (1) what this is, (2) why it is empty, (3) one primary action button to get started.

---

## 9. TandemButton

- **Purpose:** Unified interactive button component.
- **Variants:** `primary` (`color-link-direct`), `secondary` (`color-surface` with `color-border`), `quiet` (borderless), `destructive` (`color-danger`).
- **Sizes:** `md` (36px desktop / 48dp hit area), `lg` (48px / 48dp).
- **States:** default, hover, pressed, focus (2px offset ring in `color-link-direct`), disabled, loading.
