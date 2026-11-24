# Screen S4: Send (One-Off Transfer)

## 1. Overview
The Send screen enables rapid, ephemeral file and folder transfers between nearby devices without requiring internet access or permanent synchronization setup. Users pick files, choose an available nearby or paired device, and transfer immediately.

## 2. Layout
- **Container:** Vertically stacked card layout on `color-ground`.
- **File Staging Zone:** Drop-target / file-picker header card showing selected files, file count, and total byte size.
- **Recipient Picker:** List of discovered nearby devices with live link indicators.
- **Active Transfers List:** Real-time transfer rows showing progress, throughput, and time remaining.

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-link-direct`, `color-link-relay`, `color-ok`
- **Typography:** `font-sans`, `font-mono` (speed, percentages, timestamps), `text-xl`, `text-md`, `text-sm`, `text-xs`
- **Spacing:** `space-3`, `space-4`, `space-5`, `space-6`
- **Border Radius:** `radius-panel`, `radius-button`

## 4. Components
- `EmptyState` (`send.empty` with drag-and-drop prompt)
- `TandemButton` (variant: primary for "Choose files", variant: secondary for "Add folder")
- `DeviceRow` (recipient selector with `LinkLine`)
- `TransferRow` (live speed, progress bar, time left, cancel action)

## 5. States and Interactions
- **Empty State:** No files selected; clear prompt to pick files or drag them into the window.
- **Files Staged:** Displays chip list of selected items with total size. Recipient list activates.
- **Sending / Receiving State:** Progress bar with tabular monospace figures (`24.5 MB/s • 3s remaining`). Multipath badge indicates interfaces used.
- **Completed State:** Green checkmark badge with "Sent successfully" and quick action to "Send more".

## 6. Responsive Behavior
- **Desktop (>1024px):** Drag-and-drop target covers the main viewport. Two-column split between staged files and recipient selection.
- **Mobile (<768px):** Primary tab in bottom navigation. System file picker triggers on tap.

## 7. Edge Cases
- **No Nearby Devices Discovered:** Prominently links to Screen S8 (No-Internet Helper) with guided Flow B/C hotspot setup.
- **Recipient Disconnects Mid-Transfer:** Auto-resumes for 60 seconds. If unreachable, pauses with "Waiting for device to reconnect..." without losing completed blocks.
- **Very Large Files (10 GB+):** Monospace progress bar stays accurate without integer overflow.

## 8. Animation / Motion
- Monospace speed counter updates smoothly without layout jitter (uses `font-feature-settings: "tnum"`).

## 9. Accessibility Notes
- Screen reader polite announcements every 25% interval: "Transfer 50% complete, 12 seconds remaining."
- Keyboard accessible file picker trigger and cancellation buttons.
