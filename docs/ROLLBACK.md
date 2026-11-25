# Tandem Rollback and Downgrade Plan (P7)

## Principles
1. **Never delete a published tag or GitHub release.** Withdrawing a release happens by editing the release notes and marking it clearly as superseded or non-functional.
2. **Never touch user synced folders or `.tandem-trash`.** Uninstalling or downgrading `tandemd` / Tandem UI must preserve all user files, `.tandem-trash`, and device identity (`cert.pem`, `key.pem`).

## Procedure to Withdraw a Broken Release
1. On GitHub Releases, **edit** the affected release (do not delete):
   - Prepend `[WITHDRAWN - DO NOT USE]` to the title and release body.
   - Mark it as `pre-release` and link to the last known good release tag (or source build instructions if none).
2. Remove the broken version from `site/index.html` / `VERSION` only via a normal forward commit on `main` (never `git push --force` or delete git history).

## User Downgrade Steps
1. **Stop Tandem:**
   - Linux: `systemctl --user stop tandemd` (or quit Tandem).
   - Windows/macOS: quit Tandem from the tray/menu bar or Settings.
2. **Install the previous version:**
   - Linux `.deb`: `sudo dpkg -i tandem_<prev>_linux_amd64.deb`
   - Linux `AppImage`: swap back to the previous `.AppImage`.
   - Windows/macOS: run the previous installer / replace `Tandem.app`.
   - Android: note that downgrading an APK requires uninstalling first if `versionCode` decreased; back up any local `.tandem-trash` or synced folder before uninstalling.
3. **Config & Folder Compatibility Guarantee:**
   - Syncthing `config.xml` schema v37+ (`syncthing v2.1.7`) and `.tandem-trash` plain directory layout remain readable across `0.3.x` patch releases without data loss. Before bumping Syncthing major versions in future releases, add an explicit downgrade compatibility test in `tests/e2e/`.
