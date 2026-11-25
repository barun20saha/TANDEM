# Android Physical Device Test Checklist (Stage C Gates C1–C6)

Stage C stays **closed** until at least **two phones from different brands** complete this checklist with Play Protect enabled and evidence saved under `docs/evidence/android/<phone>/`.

## Pre-Checks
1. Confirm the release APK was signed with your release keystore (`~/tandem-release.jks`), **not** `CN=Android Debug`:
   ```bash
   apksigner verify --verbose --print-certs tandem-<version>-android-sideload.apk
   aapt2 dump badging tandem-<version>-android-sideload.apk | head -n 25
   ```
   Confirm `debuggable` is absent and `targetSdkVersion` is `35`+.

## Test Steps (Run on Phone A & Phone B — two different brands)
1. **Clean Install & Play Protect Dialog (Gate C3):**
   - Enable Play Protect. Install `tandem-<version>-android-sideload.apk` (and test `play` flavor separately).
   - Take screenshots of every dialog shown (`"Scan app"` prompt is expected for a new app; `"App blocked"` or `"Harmful app blocked"` is a **FAIL**).
   - Save screenshots to `docs/evidence/android/<phone>/install-*.png`.
2. **Foreground Service & Local API (Gate C1):**
   - Launch Tandem. Confirm persistent notification appears and Settings shows a real Device ID (never empty or `TANDEM-LOCAL-ID`).
3. **Wi-Fi Sync with Linux Desktop (Gate C4):**
   - Connect Phone and Linux laptop to the same Wi-Fi network.
   - Pair via QR/code. Share a folder with 100 MB + 100 files. Confirm matching SHA-256 hashes and `Direct, same network` link state.
4. **No-Internet Hotspot Sync (Gate C4):**
   - Turn off mobile data and disconnect router WAN (or use Phone's local hotspot).
   - Connect Linux laptop to the phone's hotspot. Send 10 photos/files both ways and confirm matching hashes.
5. **30-Minute Screen-Off Survival (Gate C5):**
   - Start a sync/transfer or leave `TandemService` active with screen off for 30 minutes.
   - Record phone brand, Android version, OS battery setting, and whether sync resumed/completed without OS kill.
6. **Update-over-Update Install (Gate C2):**
   - Install a rebuild signed with the same release keystore directly over the installed app (without uninstalling) and confirm data & Device ID are preserved.
