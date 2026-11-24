# Screen S8: No-Internet Helper

## 1. Overview
The No-Internet Helper guides users through establishing a local peer-to-peer connection when there is no router, no cellular data, or when client isolation blocks direct peer discovery (Flows B through E of Section 5.3).

## 2. Layout
- **Container:** Vertically scrolling step-by-step wizard.
- **Header:** Title ("Connect without internet"), current environment assessment ("No Wi-Fi router detected").
- **Flow Selector / Stepper:** Step indicator displaying progress through the selected guidance flow (B, C, D, or E).
- **QR Code Card:** Displays Wi-Fi configuration QR code (`WIFI:T:WPA;S:...;P:...;;`) for instant companion connection.
- **Footer:** Action buttons ("I'm connected", "Try another method").

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-link-direct`, `color-ok`, `color-danger`
- **Typography:** `font-sans`, `font-mono` (SSID, password, IP), `text-xl`, `text-lg`, `text-md`, `text-sm`
- **Spacing:** `space-3`, `space-4`, `space-5`, `space-6`
- **Border Radius:** `radius-panel`, `radius-button`

## 4. Components
- `BannerNotification` (flow instructions and OS-specific hints)
- `TandemButton` (variant: primary for next step, variant: secondary for back)
- QR code generator card (custom contrast-compliant renderer)

## 5. Flow-Specific Layouts
- **Flow B (Phone creates hotspot):** Guides user to toggle phone hotspot. Displays QR code containing hotspot credentials. Laptop joins via camera or Wi-Fi list.
- **Flow C (Laptop creates hotspot - Linux only):** Invokes `Hotspot.Create()`. Displays generated SSID and WPA2 passphrase.
- **Flow D (macOS guidance):** Explains that macOS cannot host offline APs; provides clear illustration to join phone hotspot.
- **Flow E (Client isolation on guest network):** Explains why devices on public/hotel Wi-Fi cannot see each other; instructs switching to mobile hotspot.

## 6. Responsive Behavior
- **Desktop (>1024px):** Centered card layout with large QR code and step progression on the right.
- **Mobile (<768px):** Single-column stepped view with large touch targets.

## 7. Edge Cases
- **Hotspot Without Mobile Data:** Clarifies with explicit callout: "Your phone does not need cellular data enabled; local Wi-Fi transmission is completely free."
- **Windows Offline Tethering Bug:** Explicitly handles Windows inability to start tethering without internet by directing Windows users to Flow B (phone host).

## 8. Animation / Motion
- Step transitions use 200ms slide-horizontal animation.

## 9. Accessibility Notes
- Wi-Fi credentials include an accessible copy button with "Copied password to clipboard" spoken feedback.
- Step indicators announce current step semantically: "Step 2 of 3: Scan Wi-Fi QR code with other device."
