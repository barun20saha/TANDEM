# Screen S1: First Run

## 1. Overview
The First Run screen greets new users immediately after initial installation and startup. It provides an immediate, clear distinction between Send (one-off transfer) and Sync (continuous folder sync) in two concise sentences, without technical jargon. Its sole call-to-action is pairing the user's first peer device.

## 2. Layout
- **Canvas:** Centered single-column container on `color-ground`.
- **Card:** Elevated card on `color-surface` with `radius-panel` border radius and `space-6` internal padding. Max container width: 480px.
- **Hierarchy:** App logo/icon at top (`space-6` top margin), followed by headline, two explanation paragraphs, and the primary action button.

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-text`, `color-link-direct`, `color-border`
- **Typography:** `font-sans`, `text-2xl` (title), `text-md` (body copy), `text-sm` (footnote)
- **Spacing:** `space-2`, `space-3`, `space-4`, `space-5`, `space-6`
- **Border Radius:** `radius-panel`, `radius-button`

## 4. Components
- `EmptyState` illustration (dual-device handshake)
- `TandemButton` (size: lg, variant: primary, full-width)
- `TandemButton` (size: md, variant: secondary, text: "Explore without pairing")

## 5. States and Interactions
- **Default State:** Displays welcome messaging and primary "Pair your first device" button.
- **Hover/Focus State:** Primary button shifts brightness per token interaction states; high-contrast focus ring enabled for keyboard navigation.
- **Action State:** Tapping "Pair your first device" opens Screen S7 (Pairing flow modal).

## 6. Responsive Behavior
- **Desktop (>1024px):** Centered modal dialog or centered card view (480px width) against subtle ground backdrop.
- **Tablet (768px - 1024px):** Centered card layout with `space-6` side margins.
- **Mobile (<768px):** Full-screen view with `space-4` padding; primary action pinned to bottom safe area for one-handed thumb reach.

## 7. Edge Cases
- **No Network Available:** Shows explanatory footnote: "No internet required. Tandem pairs directly over local Wi-Fi or hotspot."
- **Screen Reader:** Screen reader announces: "Welcome to Tandem. Send moves files once without internet. Sync keeps folders identical continuously. Button: Pair your first device."
- **RTL Languages:** Layout mirrors horizontally; illustration aligns to natural reading order.
- **Large Text Scaling (200%):** Text wraps cleanly without truncation; container vertically scrolls if viewport height is exceeded.

## 8. Animation / Motion
- Fade-in card entrance with 200ms ease-out curve.
- Disabled motion respected when OS `prefers-reduced-motion` is active.

## 9. Accessibility Notes
- Keyboard focus lands directly on the primary "Pair your first device" button.
- Color contrast between `color-text` and `color-surface` exceeds WCAG AAA (7:1).
