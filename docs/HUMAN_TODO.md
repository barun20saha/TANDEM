# Human Action Checklist (In Order)

Because the agent runs inside an offline sandbox with read-only `.git` and no access to signing keys, physical phones, or Windows/macOS hardware, complete these steps on your own machine in order.

---

## Step 1: Review and Commit Agent Changes
Review `docs/CHANGES.md` and `git status`, then commit in small single-concern commits on `main`:
```bash
git status
# Recommended commits (see docs/CHANGES.md for exact file groupings):
git add .gitignore README.md docs/CHANGES.md docs/HUMAN_TODO.md design/screenshots/ design/CRITIQUE.md app/test/screenshots_ws3_test.dart
git commit -m "chore(repo): clean up gitignore, deduplicate screenshots, and fix README links (P0)"

git add core/ docs/openapi.yaml app/test/openapi_* app/test/screens_empty_state_test.dart scripts/setup_dev.sh scripts/verify_all.sh
git commit -m "feat(core,api): add config.json port support, OpenAPI contract tests, security tests, and verify scripts (P1, P6)"

git add app/ docs/DECISIONS.md docs/ANDROID_*
git commit -m "feat(ui,android): add desktop runners, live two-daemon UI tests, live screenshots, and Android engine wiring (P2, P5)"

git add .github/ scripts/ site/ CHANGELOG.md SECURITY.md docs/
git commit -m "ci,docs: add staged CI/CD workflows, bundle syncthing in installers, and update docs/report (P3, P4, P7, P8)"
```

---

## Step 2: Install Tools & Run `verify_all.sh` on Your Linux Machine
1. Check prerequisites:
   ```bash
   bash scripts/setup_dev.sh
   ```
   If `go`, `flutter`, or `syncthing` is missing on your host, install them:
   - Go 1.24+: https://go.dev/dl/
   - Flutter stable: https://docs.flutter.dev/get-started/install
   - Pinned Syncthing `v2.1.7`: `python3 scripts/fetch_syncthing.py --out ~/.local/bin/syncthing` (ensure `~/.local/bin` is in `PATH`).
2. Run the full verification suite:
   ```bash
   bash scripts/verify_all.sh
   ```
   Paste the `VERIFY_ALL SUMMARY` block back if any step reports `FAIL`.
3. Optional desktop `integration_test` with a live window (requires `xvfb` or an active X11/Wayland session):
   ```bash
   cd app
   xvfb-run -a flutter test -d linux integration_test/app_live_test.dart
   ```
4. Run `govulncheck` (requires internet):
   ```bash
   go install golang.org/x/vuln/cmd/govulncheck@latest
   (cd core && govulncheck ./...)
   (cd tests && govulncheck ./...)
   ```

---

## Step 3: Push & Verify Stage A (`v0.3.0`) in GitHub Actions
1. Push `main`:
   ```bash
   git push origin main
   ```
2. Wait for GitHub Actions `.github/workflows/test.yml` and `.github/workflows/build-linux.yml` to turn **green** on GitHub.
3. Once Stage A is green and you want to cut the Stage A Linux pre-release (`v0.3.0`):
   ```bash
   python3 scripts/bump_version.py 0.3.0
   git add -A && git commit -m "chore(release): bump VERSION to 0.3.0 for Stage A pre-release"
   git tag v0.3.0
   git push origin main v0.3.0
   ```
   (`release.yml` creates a **draft pre-release** — review the draft on GitHub before clicking Publish, and optionally edit the old `v0.2.3` release notes to mark it non-functional and link to `v0.3.0`.)

---

## Step 4: Stage B (Windows & macOS)
1. Optional code-signing secrets in GitHub Repo Settings -> Secrets and variables -> Actions:
   - Windows: `WINDOWS_CERT_PFX_BASE64`, `WINDOWS_CERT_PASSWORD`
   - macOS: `APPLE_CERT_P12_BASE64`, `APPLE_CERT_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`
   (Without these secrets, CI still builds & smoke-tests unsigned builds, which must be labelled `unsigned`.)
2. Run `release.yml` via **Actions -> Tandem Staged Release -> Run workflow -> stage: B** (or trigger `build-windows.yml` / `build-macos.yml`).
3. Run the physical cross-OS checklist in `docs/MANUAL_TESTS.md` and record the results before removing `untested` from cross-OS sync.

---

## Step 5: Stage C (Android — Blocked Until Completed)
1. Reply with the **exact Play Protect warning dialog text / screenshot**, **phone model**, **Android version**, and **APK flavour** (`sideload` vs `play`) from your earlier test.
2. Back up your release keystore (`~/tandem-release.jks`) in a password manager / offline backup. **Never commit it.**
3. Add GitHub Actions secrets:
   - `ANDROID_KEYSTORE_BASE64` (`base64 -w 0 ~/tandem-release.jks`)
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
4. Complete Google Android Developer registration / Play Console verification for `com.tandem.sync` (required human identity step).
5. Run `build-android.yml` on GitHub, download the signed APK, and execute `docs/ANDROID_TEST_CHECKLIST.md` on **two phones from different brands**. Save screenshots to `docs/evidence/android/<phone>/`.
