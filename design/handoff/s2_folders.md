# Screen S2: Folders

## 1. Overview
The Folders screen is the primary hub for Sync mode. It displays all synchronized folders, their sync health, size, peer count, and last-synced timestamp, along with the primary action to add a new sync folder.

## 2. Layout
- **Container:** Full-height scrollable pane on `color-ground`.
- **Header:** Sticky or top header displaying view title ("Folders"), total sync throughput/status indicator, and "Add folder" button.
- **List:** Vertical stack of `FolderRow` items with `space-2` separation.

## 3. Design Tokens Used
- **Colors:** `color-ground`, `color-surface`, `color-border`, `color-text`, `color-ok`, `color-danger`, `color-link-direct`
- **Typography:** `font-sans`, `font-mono` (for file sizes), `text-xl` (header), `text-md` (folder name), `text-xs` (stats)
- **Spacing:** `space-2`, `space-3`, `space-4`, `space-5`
- **Border Radius:** `radius-panel`, `radius-button`

## 4. Components
- `FolderRow` (label, path, size, device badges, sync progress bar)
- `TandemButton` (variant: primary, icon: plus, text: "Add folder")
- `EmptyState` (`folders.empty` with prompt to select a local folder)
- `BannerNotification` (when conflicts or storage warnings exist)

## 5. States and Interactions
- **Empty State:** When no folders are synced, renders `EmptyState` explaining folder sync with an "Add folder" button.
- **Syncing State:** Live indeterminate or percentage progress bar on `FolderRow` with tabular monospace transfer numbers.
- **Error State:** Folder row displays warning badge (`color-danger`) with link to Screen S3 Folder Detail.
- **Tap Row:** Navigates to Screen S3 (Folder Detail).

## 6. Responsive Behavior
- **Desktop (>1024px):** Renders in right content pane of two-pane split view.
- **Tablet (768px - 1024px):** Full-width pane with collapsible device drawer.
- **Mobile (<768px):** Primary tab in bottom navigation bar. "Add folder" button floats at bottom right or top app bar.

## 7. Edge Cases
- **100,000 Files in Folder:** Virtualized list view recycling rows; indexing status shows "Scanning..." without freezing UI thread.
- **Very Long Folder Names:** Text truncates with middle ellipsis (`Documents/.../ProjectFinal`) preserving folder root and leaf name.
- **Offline / Paused:** Dimmed state indicator and clear paused tag (`color-text` at 50% opacity).

## 8. Animation / Motion
- Progress bar animates with smooth 150ms linear transition.
- Row tap uses subtle scale/ripple token feedback.

## 9. Accessibility Notes
- Each `FolderRow` has accessibility semantics announced as: "Folder: Work Documents, 1.4 gigabytes, sharing with 2 devices, up to date."
- Keyboard navigation supports arrow up/down between folder rows, Enter to open.
