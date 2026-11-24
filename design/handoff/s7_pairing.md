# Screen S7: Pairing

## 1. Overview
The Pairing screen facilitates the secure, zero-friction mutual authentication handshake between two devices. It presents a dynamic QR code containing the pairing URL, a camera scanner for peer QR codes, and a 6-digit confirmation code ensuring protection against man-in-the-middle attacks.

## 2. Layout
- **Modal / Card Container:** Max width 480px, centered on viewport.
- **Toggle Header:** Segmented control between "Show QR code" and "Scan QR code".
- **QR Presentation Area:** High-contrast QR code rendered on white backing canvas (`240x240px`), surrounded by `space-4` padding.
- **Verification Code Box:** Monospace 6-digit code with large letter-spacing (`text-2xl`, bold).
- **Peer Approval Card:** Displayed when a pairing request is received, showing requester device name, IP, and fingerprint.

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-link-direct`, `color-ok`, `color-danger`
- **Typography:** `font-sans`, `font-mono` (6-digit code, fingerprint), `text-2xl`, `text-lg`, `text-md`, `text-sm`
- **Spacing:** `space-3`, `space-4`, `space-5`, `space-6`
- **Border Radius:** `radius-panel`, `radius-button`

## 4. Components
- `PairingPanel` (camera preview, QR renderer, 6-digit verification code)
- `TandemButton` (variant: primary for "Confirm match", variant: secondary for "Cancel")
- `ConfirmDialog` (if peer fingerprint mismatch occurs)

## 5. States and Interactions
- **Show Code:** Generates ephemeral pairing URI with 5-minute expiry.
- **Scan Code:** Launches camera viewfinder with animated alignment reticle.
- **Confirm Match:** Displays identical 6-digit numeric code on both screens. Both users tap "Confirm".
- **Paired Success:** Screen smoothly transitions with green checkmark and "Devices paired" toast.

## 6. Responsive Behavior
- **Desktop (>1024px):** Center modal dialog with ESC key dismiss. Desktop displays QR code and accepts manual code entry or camera scan if webcam available.
- **Mobile (<768px):** Full-screen view with camera permission prompt.

## 7. Edge Cases
- **Camera Permission Denied:** Seamlessly falls back to entering the 6-digit code or pasting device address manually.
- **Pairing Code Expired:** Displays "Code expired" with one-tap "Generate new code" button.

## 8. Animation / Motion
- QR scan reticle pulses with gentle 1.5s ease-in-out loop.
- Screen transitions to success state using 250ms scale-fade.

## 9. Accessibility Notes
- The 6-digit confirmation code is semantically announced as separate digits: "Verification code: 8 4 9 2 0 1" to avoid screen-reader misinterpretation as large numbers.
- Esc key dismisses dialog cleanly and restores previous focus.
