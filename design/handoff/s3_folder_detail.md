# Screen S3: Folder Detail

## 1. Overview
The Folder Detail screen provides comprehensive inspection and configuration for a single synchronized folder: its file inventory, sharing peers, active conflicts, trash retention/recovery view, and folder sync mode.

## 2. Layout
- **Header:** Folder name, path breadcrumb, pause/resume toggle, and folder sync mode badge (`sendreceive`, `sendonly`, `receiveonly`).
- **Body Sections:**
  1. Sharing Devices (chips with `LinkLine` badges)
  2. Conflict Banner (if conflicts exist)
  3. Trash Retention & One-Click Recovery (`.tandem-trash` count and size)
  4. File List / Recent Changes
  5. Danger Zone ("Stop syncing folder" button)

## 3. Design Tokens Used
- **Colors:** `color-surface`, `color-ground`, `color-border`, `color-text`, `color-ok`, `color-danger`, `color-link-direct`, `color-link-relay`
- **Typography:** `font-sans`, `font-mono` (paths, hashes), `text-lg`, `text-md`, `text-sm`, `text-xs`
- **Spacing:** `space-2`, `space-3`, `space-4`, `space-5`, `space-6`
- **Border Radius:** `radius-panel`, `radius-button`, `radius-badge`

## 4. Components
- `BannerNotification` (conflict warnings with resolution actions)
- `TandemButton` (variant: secondary for pause, danger for stop syncing)
- `ConfirmDialog` (`stop.confirm` ensuring local files are kept intact)
- `DeviceRow` (sub-list of peers sharing this folder)

## 5. States and Interactions
- **In Sync:** Green check badge (`color-ok`) with "Up to date".
- **Conflicts Detected:** Yellow/Orange banner warning of conflicting edits with "Review conflicts" button.
- **Trash Recovery Action:** Clicking "Recover deleted files" opens modal listing files inside `.tandem-trash` with "Restore" buttons.
- **Mode Switching:** Dropdown to switch between "Send & Receive", "Send Only", and "Receive Only" (with clear explanation of each).

## 6. Responsive Behavior
- **Desktop (>1024px):** Slides into right content pane or modal sheet.
- **Mobile (<768px):** Full-screen pushed route with back navigation arrow.

## 7. Edge Cases
- **Low Disk on Device:** Prominent persistent warning banner (`err.disk_full`) disabling incoming sync until freed.
- **File Deletion:** Reminder that all deletes are retained in `.tandem-trash` for 30 days before permanent deletion.
- **RTL:** Breadcrumb paths and badge alignments respect text direction.

## 8. Animation / Motion
- Conflict banner slides in vertically with 200ms ease-out.

## 9. Accessibility Notes
- Screen reader announces: "Folder Work Documents. Send and Receive mode. Up to date. 2 shared devices. 0 conflicts. Trash contains 3 deleted items."
- Destructive "Stop syncing" button prompts accessible modal dialog with trapped keyboard focus.
