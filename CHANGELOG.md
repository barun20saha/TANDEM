# Changelog

All notable changes to Tandem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Staged CI/CD workflows (`.github/workflows/test.yml`, `build-linux.yml`, `build-windows.yml`, `build-macos.yml`, `build-android.yml`, `release.yml`) with clean-container Linux `.deb` smoke tests and `apksigner` debug-key rejection checks.
- Developer setup and full Stage A verification scripts (`scripts/setup_dev.sh`, `scripts/verify_all.sh`).
- OpenAPI contract parity tests in Go (`core/api/contract_test.go`) and Dart (`app/test/openapi_contract_test.dart`, `app/test/openapi_mock_validator.dart`), plus loopback/pairing security tests (`core/api/security_test.go`).
- Flutter desktop runner scaffolds (`linux`, `windows`, `macos`), `app/integration_test/app_live_test.dart`, and `app/test/live_daemon_ui_test.dart` capturing real two-daemon live screenshots under `design/screenshots/live/`.
- Per-instance `config.json` port configuration (`core/engine/config.go`), Android real engine bridge wiring (`core/pal_android/bridge.go`), and documentation (`docs/SECURITY_REVIEW.md`, `docs/ROLLBACK.md`, `docs/MANUAL_TESTS.md`, `docs/ANDROID_PERMISSIONS.md`, `docs/ANDROID_TEST_CHECKLIST.md`, `docs/FINAL_REPORT.md`).

### Fixed
- Bundled pinned `syncthing` binary in Linux, Windows, and macOS packaging scripts (`scripts/package_deb.sh`, `package_windows.ps1`, `package_macos.sh`) plus Windows uninstall firewall cleanup without touching user folders.
- Fixed `FirstRunScreen` triggering when unpaired nearby devices exist (`pairedDevices.isEmpty`), zero-timestamp `0001-01-01` formatting in `lastSeen`, and `docs/openapi.yaml` schema alignment (`SystemHealth`, `SendSession`, `DaemonStatus`, `Folder`).

### Known Issues
- Prior `v0.2.3` release is non-functional (stub engine, gallery UI, debug-signed Android APK).
- Windows, macOS, and Android remain runtime-untested until CI Stage B/C runners and physical phone tests complete.

## [0.2.3] - 2026-11-25

### Fixed
- Fixed Dart constructor errors in `app/lib/screens/activity_screen.dart` (`TransferRow`), `app/lib/screens/health_check_screen.dart` (`BannerNotification`), and `app/lib/screens/folder_detail_screen.dart` (`BannerNotification`) so `flutter analyze` passes cleanly.
- Guarded RPM packaging in `scripts/package_deb.sh` to native host architecture (`x86_64` on `amd64`) and fixed `AppDir/usr/bin/tandem` symlink for AppImage validation.

## [0.2.2] - 2026-11-25

### Fixed
- Added `design/tandem.png` and `.DirIcon` to AppImage packaging in `scripts/package_deb.sh` so `appimagetool` builds `tandem-<version>-linux-x86_64.AppImage` cleanly.
- Removed unused `empty_state.dart` import from `app/lib/screens/first_run_screen.dart` so `flutter analyze` completes cleanly.
- Updated `.github/workflows/pages.yml` to publish `site/` directly to the `gh-pages` branch.

## [0.2.1] - 2026-11-25

### Added
- Unified GitHub Pages OS-detecting download portal (`site/index.html` + `.github/workflows/pages.yml`) giving visitors one link tailored to Windows, macOS, Linux, or Android.
- Windows Inno Setup `.exe` installer (`scripts/tandem_installer.iss`) with optional Authenticode signing and firewall configuration.
- Linux single-file `AppImage` and `.rpm` packaging alongside `.deb` and `.tar.gz` in `scripts/package_deb.sh`.
- `core/cmd/tandemd_android` C-shared entrypoint for Android `libtandemd.so` NDK compilation.

### Fixed
- Removed deprecated `package` attribute from `app/android/app/src/main/AndroidManifest.xml` for Android Gradle Plugin 8+ compatibility and added AndroidX dependencies for `TandemService.kt`.
- Fixed `flutter analyze` deprecated `ColorScheme` properties in `app/lib/main.dart` and added `app/analysis_options.yaml`.
- Updated `security.yml` to run `govulncheck` on the latest stable Go toolchain and handle unconfigured Dependency Graph gracefully.

## [0.2.0] - 2026-11-25

### Added
- Centralized Semantic Versioning (`VERSION`) and `scripts/bump_version.py` release version manager supporting `stable`, `alpha`, `beta`, and `rc` channels.
- Build-time version, Git commit SHA, build timestamp, and release channel injection (`-ldflags`) into `tandemd` with `-version` and `-version-json` flags.
- Multi-platform GitHub Actions release pipeline (`.github/workflows/release.yml`) building and publishing artifacts for:
  - **Windows** (`amd64`, `arm64` portable `.zip` bundles with `tandemd.exe`, Flutter desktop UI, and firewall helper).
  - **macOS** (Universal `.app` & `.dmg`/`.tar.gz` with `tandemd` universal binary and `NSLocalNetworkUsageDescription`).
  - **Linux** (`.deb` and `.tar.gz` bundles for `amd64` and `arm64` with `systemd --user` service unit).
  - **Android** (`sideload` APK with `MANAGE_EXTERNAL_STORAGE` and `play` AAB/APK per Decision D5, plus embedded `libtandemd.so` ABI libraries).
- Supply-chain security & release integrity: `SHA256SUMS.txt`, `release-manifest.json`, GitHub build provenance attestations, and `.github/workflows/security.yml` (`govulncheck` + dependency review).
- Organization-grade GitHub governance & community files: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `.github/CODEOWNERS`, `.github/dependabot.yml`, `.github/release.yml`, structured issue forms, and pull request template.

### Changed
- Updated `scripts/package_deb.sh`, `scripts/package_macos.sh`, `scripts/package_windows.ps1`, and added `scripts/package_android.sh` to read from `VERSION` and support multi-architecture packaging.
- Hardened `.github/workflows/ci.yml` with `flutter analyze`, cross-platform daemon builds, and packaging smoke validation.

## [0.1.0-alpha.1] - 2026-11-24

### Added
- Initial `tandemd` Go daemon with Platform Abstraction Layer (PAL) adapters for Linux, Windows, macOS, and Android.
- Localhost REST & SSE API server (`127.0.0.1:8385`) with Bearer API key authentication and OpenAPI 3.0 spec.
- Cross-OS compatibility guards (`core/engine/compat`), `.tandem-trash` 30-day recovery store, multipath scheduler, link manager, and QR/6-digit pairing service.
- Flutter UI screens (`S1`–`S11`) and design system token compiler/auditor (`design/audit.py` at 100% token coverage).
- Chaos test suite (`tests/chaos`) and self-hosted relay/discovery Docker Compose stack (`infra/`).

[Unreleased]: https://github.com/barun20saha/TANDEM/compare/v0.2.3...HEAD
[0.2.3]: https://github.com/barun20saha/TANDEM/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/barun20saha/TANDEM/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/barun20saha/TANDEM/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/barun20saha/TANDEM/compare/v0.1.0-alpha.1...v0.2.0
[0.1.0-alpha.1]: https://github.com/barun20saha/TANDEM/releases/tag/v0.1.0-alpha.1
