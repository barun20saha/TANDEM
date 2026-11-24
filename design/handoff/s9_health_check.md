# Screen S9: Health Check

## 1. Overview
The Health Check screen is a self-diagnostic center that validates system-level prerequisites: local network permissions, firewall rules, background battery optimization status, disk space, and UDP discovery loopback capability. Each detected issue includes a direct, one-click remediation action.

## 2. Layout
- **Header:** Overall health status banner ("All systems operational" or "2 actions required").
- **Diagnostic List:** Grouped card list of platform subsystem checks:
  1. Discovery Self-Test (UDP 21027 loopback)
  2. Local Network Privacy Permission (macOS 15+ / iOS)
  3. Firewall Rules (Linux ufw/firewalld, Windows Defender)
  4. Background Service & Battery Optimization (Android)
  5. Storage & File System (inotify watches, disk free space)

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-ok`, `color-danger`, `color-link-direct`
- **Typography:** `font-sans`, `font-mono` (ports, paths), `text-xl`, `text-md`, `text-sm`, `text-xs`
- **Spacing:** `space-2`, `space-3`, `space-4`, `space-5`
- **Border Radius:** `radius-panel`, `radius-button`, `radius-badge`

## 4. Components
- `BannerNotification` (status alerts with color-coded severity)
- `TandemButton` (variant: primary or secondary for fix actions, e.g. "Open system settings", "Fix firewall rules")

## 5. States and Interactions
- **Passed Check:** Green check circle icon with "Working properly".
- **Warning Check:** Amber warning triangle with remediation advice (e.g., "Battery optimization may pause background sync").
- **Failed Check:** Red alert octagon with primary action button (e.g., "Open Windows Firewall settings").
- **Re-test Action:** "Run diagnostics again" button at bottom of screen.

## 6. Responsive Behavior
- **Desktop (>1024px):** Two-column grid of diagnostic cards.
- **Mobile (<768px):** Vertical single-column stack.

## 7. Edge Cases
- **Linux inotify Exhaustion:** Explains `fs.inotify.max_user_watches` with copyable `sysctl` command.
- **macOS Sequoia Local Network Revocation:** Guides user directly into System Settings > Privacy & Security > Local Network.

## 8. Animation / Motion
- Diagnostic checks run with staggered checkmark reveals (50ms offset per item).

## 9. Accessibility Notes
- Severity announced explicitly: "Warning: Battery optimization enabled. Tap to open system settings."
- High-contrast color tokens guarantee visibility across light and dark modes.
