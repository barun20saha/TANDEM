# Change Summary for Commit (Generated in Offline Sandbox)

Because `.git` is read-only inside the agent sandbox, all edits below are staged on disk for the human to review and commit.

## P0 — Repository Hygiene & README
- `.gitignore`: Added `*.jks`, `*.keystore`, `key.properties`, `api.key`, `engine.key`, `*.p12`, `*.pfx`, `*.pem`, `.env`, `dist/`, `release-assets/`, `*.deb`, `*.rpm`, `*.AppImage`, `*.dmg`, `*.zip`, `*.tar.gz`, `app/android/app/src/main/jniLibs/`.
- Removed duplicate `docs/evidence/screenshots/`; consolidated on `design/screenshots/` and updated `app/test/screenshots_ws3_test.dart` and `design/CRITIQUE.md`.
- `scripts/bump_version.py`: Extended to synchronize `scripts/tandem_installer.iss` and `scripts/package_macos.sh`.
- `README.md`: Replaced absolute `file:///` link with relative `THIRD_PARTY_NOTICES.md`; documented Go, Flutter, Python, Syncthing v2.1.7 prerequisites, `scripts/setup_dev.sh`, and `scripts/verify_all.sh`.

## P1 & P6 — Engine Config, OpenAPI Contract Parity, Security & Verification Scripts
- `core/engine/config.go`, `core/cmd/tandemd/main.go`, `core/engine/config_test.go`: Added per-instance `config.json` loading (`bind`, `syncPort`, `discoveryPort`, `deviceName`, etc.) with CLI flag overrides and `0600` key permission tests.
- `docs/openapi.yaml`, `core/api/server.go`: Aligned schemas (`DaemonStatus`, `SystemHealth`, `Folder`, `SendSession`, `Device`) and suppressed zero-value `0001-01-01T00:00:00Z` `lastSeen` timestamps.
- `core/api/contract_test.go`, `core/api/security_test.go`: Added OpenAPI schema/enum + 401 auth parity tests across all routes, non-loopback `403` rejection test, and pairing mismatch rejection test.
- `app/test/openapi_mock_validator.dart`, `app/test/openapi_contract_test.dart`: Added OpenAPI spec validator wrapping test `MockClient` handlers (`screens_empty_state_test.dart`, `screenshots_ws3_test.dart`) and verifying `ApiClient` + `models.dart`.
- `scripts/setup_dev.sh`, `scripts/verify_all.sh`: Added explicit `PASS`/`FAIL` environment and Stage A verification runners saving logs to `docs/evidence/`.
- `SECURITY.md`, `docs/SECURITY_REVIEW.md`: Updated supported versions/scope and documented all P6 checks.

## P2 — Live Two-Daemon UI & Desktop Runners
- Generated Flutter desktop runners (`app/linux/`, `app/windows/`, `app/macos/`) and added `NSLocalNetworkUsageDescription` to `app/macos/Runner/Info.plist`.
- Added `integration_test` to `app/pubspec.yaml` and created `app/integration_test/app_live_test.dart` (`xvfb-run` target).
- Created `app/test/live_daemon_ui_test.dart`: boots two real `tandemd` + `syncthing` instances, pairs them over loopback HTTP, syncs real files, tests `401` error screen, and captures `design/screenshots/live/*.png` (`1920`, `1280`, `390` light/dark).
- Fixed `HomeShell` (`pairedDevices.isEmpty && folders.isEmpty` for `FirstRunScreen`), `TandemApp._boot()` (`ViewLoadState` guard), and `formatLastSeen()` in `app/lib/utils/formatters.dart`.

## P3 & P4 — CI/CD Workflows & Installers
- Replaced `.github/workflows/ci.yml` with `.github/workflows/test.yml`, `build-linux.yml`, `build-windows.yml`, `build-macos.yml`, `build-android.yml`, and `release.yml`.
- Updated `scripts/package_deb.sh`, `scripts/package_windows.ps1`, `scripts/tandem_installer.iss`, and `scripts/package_macos.sh` to bundle pinned `syncthing`, firewall configs/cleanup on uninstall, and never delete user folders.

## P5, P7 & P8 — Android Prep, Site & Final Docs
- `core/pal_android/bridge.go`, `core/cmd/tandemd_android/main.go`, `core/pal_android/bridge_test.go`, `app/android/.../TandemService.kt`, `AndroidManifest.xml`, `scripts/package_android.sh`: Replaced boolean stub with real `api.Server` + `SyncthingEngine` lifecycle, `extractNativeLibs="true"`, `targetSdk 35`, and strict release `key.properties` signing (no debug fallback).
- `docs/DECISIONS.md` (`D7`), `docs/ANDROID_PERMISSIONS.md`, `docs/ANDROID_TEST_CHECKLIST.md`, `docs/ROLLBACK.md`, `docs/MANUAL_TESTS.md`, `docs/PLATFORM_STATUS.md`, `docs/FINAL_REPORT.md`, `CHANGELOG.md`, `site/index.html`.
