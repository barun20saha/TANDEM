# Screen S10: Settings

## 1. Overview
The Settings screen provides user configuration over network transfer limits, metered connection rules, relay usage policies, startup behavior, privacy ("Hide from this network"), and trash retention duration.

## 2. Layout
- **Grouped Settings List:** Scrollable list divided into distinct sections:
  1. Network & Transfers (Wi-Fi only, metered networks, bandwidth limits)
  2. Relays & Servers (Enable global relaying, private relay URL, custom discovery server)
  3. Privacy & Discovery ("Hide from this network", discovery broadcasts)
  4. Storage & Trash (Trash retention days slider [default: 30], clear trash button)
  5. System (Start on boot/login, run in background, language)

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-link-direct`, `color-danger`
- **Typography:** `font-sans`, `font-mono` (server URLs, IP addresses), `text-xl`, `text-md`, `text-sm`, `text-xs`
- **Spacing:** `space-2`, `space-3`, `space-4`, `space-5`
- **Border Radius:** `radius-panel`, `radius-button`

## 4. Components
- Standard switch/toggle tiles styled with `color-link-direct`
- Monospace URL text inputs with validation
- `TandemButton` (variant: danger for "Empty trash now")
- `ConfirmDialog` (`trash.empty.confirm`)

## 5. States and Interactions
- **Wi-Fi Only Toggle:** Immediately pauses transfers if active interface is cellular.
- **Hide From This Network:** Temporarily silences UDP 21027 broadcast announcements on the current Wi-Fi SSID.
- **Custom Relay Configuration:** Allows entering private `strelaysrv` addresses (supports self-hosted infra).

## 6. Responsive Behavior
- **Desktop (>1024px):** Max container width 680px centered in viewport.
- **Mobile (<768px):** Full-width settings list reachable from app header icon.

## 7. Edge Cases
- **Invalid Relay URL:** Inline validation error with clear format helper text (`relay://host:port/?id=...`).
- **Trash Slider at Minimum:** Minimum selectable retention is 7 days to prevent accidental data loss; permanently disabling trash is prohibited per Rule 6.

## 8. Animation / Motion
- Smooth toggle switches with standard 150ms slide duration.

## 9. Accessibility Notes
- Toggles carry full accessibility labels (e.g. "Sync on metered connections, currently off, double tap to toggle").
- Keyboard Tab key traverses all form controls in strict logical sequence.
