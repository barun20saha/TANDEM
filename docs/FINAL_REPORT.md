# Tandem Final Verification & Gate Report

**Repository Head at Start:** `9773c52` (local edits staged on disk for commit; see [docs/CHANGES.md](CHANGES.md))  
**Target Version:** `0.2.3` in `VERSION` (Stage A `v0.3.0` bump held until CI Stage A passes & human approves release)

---

## 1. Stage Gate Status Table

### Stage A — Linux Desktop (`v0.3.0` pre-release target)

| Gate | Requirement | Status | Evidence Path | Owner |
|---|---|---|---|---|
| **A1** | Go `vet`, `build`, and `test -race` pass (locally verified; CI workflow ready) | **green (local) / not run (CI)** | `docs/evidence/verify-go-race-*.log`, `.github/workflows/test.yml` | Agent (local) / CI (on push) |
| **A2** | WS1 E2E tests (10/10) pass with logs | **green (local) / not run (CI)** | `docs/evidence/verify-e2e-*.log`, `tests/e2e/e2e_test.go` | Agent (local) / CI (on push) |
| **A3** | `tandemd` reports API/sync/discovery ready; `ss -lntup` confirms TCP/UDP sync & UDP discovery | **green (local)** | `docs/evidence/verify-ports-*.log` | Agent / Human |
| **A4** | OpenAPI contract parity (`docs/openapi.yaml`) + `401` auth on all routes; no drifting mocks | **green** | `core/api/contract_test.go`, `app/test/openapi_contract_test.dart`, `app/test/openapi_mock_validator.dart` | Agent |
| **A5** | `flutter analyze`, widget tests, live two-daemon UI test & `design/screenshots/live/*.png` | **green (local) / not run (`xvfb-run` native Linux binary)** | `design/screenshots/live/`, `app/test/live_daemon_ui_test.dart`, `app/integration_test/app_live_test.dart` | Agent (widget/live HTTP) / CI (`xvfb-run`) |
| **A6** | Clean-container `.deb`/AppImage install + packaged two-instance 1 GB + 1,000 files smoke sync | **not run** | `.github/workflows/build-linux.yml` (implemented; awaiting GitHub runner) | CI / Human |
| **A7** | Data-safety tests (trash restore, atomic writes, `kill -9` resume, disk full) | **green (local)** | `tests/e2e/e2e_test.go`, `core/engine/compat/rules_test.go` | Agent |
| **A8** | Security checklist (P6) complete | **partly green (`govulncheck` not run offline)** | `docs/SECURITY_REVIEW.md`, `core/api/security_test.go` | Agent / CI (`security.yml`) |

### Stage B — Windows & macOS (`v0.4.0` target)

| Gate | Requirement | Status | Evidence Path | Owner |
|---|---|---|---|---|
| **B1** | CI builds Windows & macOS; silent install + firewall check (Win) / bundle embedded daemon health (macOS) | **not run** | `.github/workflows/build-windows.yml`, `.github/workflows/build-macos.yml` | CI |
| **B2** | Two-instance sync test on Windows & macOS runners | **not run** | `.github/workflows/build-windows.yml`, `.github/workflows/build-macos.yml` | CI |
| **B3** | Code signing & notarization (or unsigned with first-run steps) | **not run** | `scripts/package_windows.ps1`, `scripts/package_macos.sh`, `site/index.html` | Human (secrets) / CI |
| **B4** | Real cross-OS network manual checklist (Linux <-> Windows <-> macOS) | **not run** | `docs/MANUAL_TESTS.md` | Human |

### Stage C — Android (`v0.5.0` target)

| Gate | Requirement | Status | Evidence Path | Owner |
|---|---|---|---|---|
| **C1** | Real engine on Android (stub replaced) | **partly done (Go code wired; NDK & phone runtime untested)** | `core/pal_android/bridge.go`, `core/cmd/tandemd_android/main.go`, `docs/DECISIONS.md` (`D7`) | Agent / CI |
| **C2** | Release keystore signing; `apksigner` rejects `Android Debug` | **not run (awaiting CI secrets)** | `scripts/package_android.sh`, `.github/workflows/build-android.yml` | Human (keystore) / CI |
| **C3** | Clean install on 2 different phone brands with no blocked/harmful dialog | **not run** | `docs/ANDROID_TEST_CHECKLIST.md` | Human |
| **C4** | Phone <-> Linux Wi-Fi & no-internet hotspot sync with matching hashes | **not run** | `docs/ANDROID_TEST_CHECKLIST.md` | Human |
| **C5** | Foreground service survives 30 min screen-off | **not run** | `app/android/app/src/main/kotlin/com/tandem/sync/TandemService.kt` | Human |
| **C6** | Every permission justified | **green (documented)** | `docs/ANDROID_PERMISSIONS.md` | Agent |

---

## 2. Stage Publication Readiness
- **Ready to publish right now?** **No.**
  - **Stage A (`v0.3.0` Linux pre-release):** Almost ready — local Go, E2E, `ss -lntup`, OpenAPI contract, design audit, and live two-daemon Flutter UI tests are green, **but** changes must first be committed/pushed by the human so `test.yml` and `build-linux.yml` pass **A1, A2, A5 (`xvfb-run`), A6 (packaged `.deb` clean-container smoke test), and A8 (`govulncheck`)** on GitHub Actions, followed by human review of the draft release.
  - **Stage B (`v0.4.0` Windows/macOS):** **Not ready** — neither OS has run in CI or on physical hardware.
  - **Stage C (`v0.5.0` Android):** **Closed / blocked** — awaits human Play Protect dialog text/phone info, keystore secrets in GitHub Actions, developer console registration, and physical phone verification on two devices.

---

## 3. What the Human Must Do Next (In Order)
See [docs/HUMAN_TODO.md](HUMAN_TODO.md) for copy-paste commands:
1. Review `docs/CHANGES.md` and commit the local changes on `main`.
2. Run `bash scripts/setup_dev.sh` and `bash scripts/verify_all.sh` on your machine, plus `govulncheck ./...`.
3. Push `main` to run `.github/workflows/test.yml` and `.github/workflows/build-linux.yml` on GitHub Actions.

### Next Three Recommended Tasks
1. **Commit, push, and pass Stage A CI (`test.yml` + `build-linux.yml`)**, then review and approve the `v0.3.0` Linux draft pre-release (and mark `v0.2.3` non-functional).
2. **Unblock Stage C Android** by sharing the exact Play Protect warning dialog text/screenshot, phone model, and Android version, and uploading `ANDROID_KEYSTORE_*` secrets to GitHub Actions.
3. **Run Stage B CI + `docs/MANUAL_TESTS.md`** on Windows and macOS runners/devices before promoting `v0.4.0`.
