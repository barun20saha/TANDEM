# Screen S6: Device Detail & Link Status

## 1. Overview
The Device Detail & Link Status screen provides full transparency into the peer-to-peer transport layer: active connection mode, per-interface packet and byte counters (Plexo multipath model), link speed history, relay disclosure, and security verification.

## 2. Layout
- **Header:** Device name, device model/OS, and primary connection badge.
- **Connection Visualizer:** Prominent `LinkLine` graphic displaying the live link between This Device and the selected peer.
- **Interface Breakdown Table:** Monospace data table listing active interfaces (e.g., Wi-Fi `192.168.1.45:22000`, Ethernet `10.0.0.12:22000`), connection type, and throughput.
- **Relay Warning / Upgrade Advice:** Visible if connection is relayed.
- **Advanced Section:** Collapsible card with full 56-character Syncthing Device ID and TLS certificate fingerprint.
- **Footer:** "Unpair device" destructive action.

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-link-direct`, `color-link-relay`, `color-link-relay-text`, `color-danger`
- **Typography:** `font-sans`, `font-mono` (Device ID, IP, port, latency), `text-xl`, `text-lg`, `text-md`, `text-sm`, `text-xs`
- **Spacing:** `space-3`, `space-4`, `space-5`, `space-6`
- **Border Radius:** `radius-panel`, `radius-button`

## 4. Components
- `LinkLine` (detailed inspection mode)
- `BannerNotification` (`link.relayed.help` informing that data is end-to-end encrypted but throughput is constrained)
- `TandemButton` (variant: danger, text: "Unpair device")
- `ConfirmDialog` (`unpair.confirm`)

## 5. States and Interactions
- **Direct Local Connection:** Shows LAN IP, MTU, zero relay hops, latency (<2ms).
- **Relayed Connection:** Amber banner with button "Try direct connection now" (triggers LAN UDP re-scan).
- **Unpair Confirmation:** Dialog warns that ongoing sync will cease, but no existing local files will be deleted.

## 6. Responsive Behavior
- **Desktop (>1024px):** Fills right pane of the desktop two-pane layout.
- **Mobile (<768px):** Pushed as full-screen route or bottom sheet from the Devices tab.

## 7. Edge Cases
- **Dynamic Link Migration:** Real-time UI transition when connection seamlessly upgrades from relayed to direct-local without interrupting file transfers.
- **Long Device ID:** Monospace ID with one-tap copy button and visual chunking (`XXXX-XXXX-XXXX-...`).

## 8. Animation / Motion
- Interface throughput graphs render smooth SVG line paths.

## 9. Accessibility Notes
- Monospace device ID has explicit label: "Full device identifier, tap to copy."
- High-contrast text on relay warning badges (`color-link-relay-text` on `color-link-relay-ground`).
