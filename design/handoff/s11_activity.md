# Screen S11: Activity Log

## 1. Overview
The Activity Log screen provides an audit trail of all recent sync events, one-off Send transfers, restored trash items, connection upgrades, and error notices. It provides transparency into exactly what files were transferred and when.

## 2. Layout
- **Header:** View title ("Activity"), filter chips (All, Transfers, Sync, Warnings, Trash), and "Export log" action.
- **Log Stream:** Reverse chronological list of activity events grouped by day (Today, Yesterday, Older).

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-ok`, `color-danger`, `color-link-direct`
- **Typography:** `font-sans`, `font-mono` (file names, sizes, timestamps), `text-xl`, `text-md`, `text-sm`, `text-xs`
- **Spacing:** `space-2`, `space-3`, `space-4`, `space-5`
- **Border Radius:** `radius-panel`, `radius-badge`

## 4. Components
- `TransferRow` (completed transfer record with timestamp and peer device)
- Filter chips with active state tokens
- `EmptyState` (`activity.empty` when no transfers have occurred)
- `TandemButton` (variant: secondary for "Clear history")

## 5. States and Interactions
- **Filter Selection:** Tapping "Transfers" filters stream to only Send/Receive events; tapping "Trash" displays file restorations and deletions.
- **Tap Event:** Expands event details showing full file path, peer name, transfer speed, and duration.
- **Conflict Record:** Shows "Conflict resolved: Maya's copy kept, local version renamed to file.sync-conflict-...".

## 6. Responsive Behavior
- **Desktop (>1024px):** Multi-column table view with sortable columns (File, Device, Time, Speed, Status).
- **Mobile (<768px):** Vertical feed with compact summary rows.

## 7. Edge Cases
- **10,000+ Activity Items:** Backed by SQLite event store with lazy loading / pagination in batches of 50.
- **Long File Paths:** Displays file basename prominently with directory path truncated above it.

## 8. Animation / Motion
- New activity items prepend with gentle 150ms height expansion.

## 9. Accessibility Notes
- Each activity row has full screen-reader label: "Received photo.jpg, 4.2 megabytes from Maya's Phone, completed 5 minutes ago."
- High-contrast badges for success (`color-ok`) and failure (`color-danger`).
