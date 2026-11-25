# Cross-OS Manual Verification Checklist (Stage B — Gate B4)

GitHub Actions runners test Linux, Windows, and macOS **individually** (two instances on the same runner). Real cross-OS networking across physical hardware **must** be verified manually by the human before removing the `untested` label from cross-OS sync.

Save logs/screenshots of each run in `docs/evidence/manual/`.

| # | Pair | Scenario | Expected Result | Status | Notes / Evidence |
|---|---|---|---|---|---|
| 1 | Linux <-> Windows | Same Wi-Fi with internet | Devices discover via UDP 21027, pair with 6-digit code match, sync 1 GB + 1,000 small files with matching SHA-256, `LinkLine` = `Direct, same network`. | Not run | |
| 2 | Linux <-> macOS | Same Wi-Fi, WAN unplugged (no internet) | Local discovery works without internet; macOS Local Network prompt granted; files sync with matching SHA-256. | Not run | |
| 3 | Windows <-> macOS | Phone hotspot (mobile data off) | Both laptops join phone hotspot; transfer 1 GB both ways with matching SHA-256. | Not run | |
| 4 | Any pair | Guest Wi-Fi with client isolation | Devices fail direct discovery; Health Check / No-Internet Helper guides to phone hotspot flow. | Not run | |
| 5 | Any pair | Different networks (ordinary NAT) | Link transitions to `Direct, over the internet` (dashed blue `LinkLine`). | Not run | |
| 6 | Any pair | Hard NAT forcing relay -> direct upgrade | Link reports `Through a relay (slower)` honestly with warning banner, then upgrades to direct without restarting transfer. | Not run | |
| 7 | Linux <-> Windows | Delete file on A -> restore from `.tandem-trash` on B | Deleted file lands in B's `.tandem-trash` and restores cleanly via UI. | Not run | |
| 8 | Linux <-> Windows | Reserved names (`CON.txt`) & case collision (`Photo.jpg` / `photo.jpg`) | Warnings appear in Folder Detail without data loss or crash. | Not run | |
| 9 | Linux / Windows / macOS | Uninstall & reinstall | Uninstall removes binaries and firewall rules; user synced folders and `.tandem-trash` remain intact. | Not run | |
