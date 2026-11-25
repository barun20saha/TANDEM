# Tandem Security & Quality Review (P6)

**Status:** Stage A security checks verified on Linux; `govulncheck` requires network (scheduled in `.github/workflows/security.yml` and documented for local runs).

| Check | Requirement | Verification & Evidence | Status |
|---|---|---|---|
| **Loopback-only API** | `tandemd` binds strictly to `127.0.0.1` and rejects non-loopback `RemoteAddr` with `403 Forbidden`. | `requireAuth` in `core/api/server.go`; verified by `TestSecurity_LoopbackOnlyAndPairingConfirmationGate` in `core/api/security_test.go` and `ss -lntup` (`127.0.0.1:18385`). | **PASS** |
| **Owner-only keys & certs (`0600`)** | `api.key`, `engine.key`, `syncthing/cert.pem`, `syncthing/key.pem`, `config.xml` have `0600` perms. | Verified by `TestDefaultConfig_SeparateInstancesViaConfigFileAndPermissions` (`core/engine/config_test.go`) and `TestE2E_BootAndAuth` (`tests/e2e/e2e_test.go`). | **PASS** |
| **API authentication (`401`)** | Missing or invalid `Bearer` token returns `401` on every documented endpoint. | Verified across all routes in `docs/openapi.yaml` by `TestOpenAPIContractAndAuthParity` (`core/api/contract_test.go`) and `TestE2E_BootAndAuth`. | **PASS** |
| **Mutual pairing confirmation** | Unconfirmed / mismatched code rejected; unconfirmed peer cannot receive folders. | Verified by `TestSecurity_LoopbackOnlyAndPairingConfirmationGate` (`core/api/security_test.go`) and `TestLocalAPIEndpoints/PairingFlow`. | **PASS** |
| **Filename & path traversal safety** | `../`, absolute paths, symlink escapes, reserved Windows names, and case collisions rejected/warned. | Verified by `TestSafePathEscapePrevention`, `TestWindowsReservedNames`, `TestDetectCaseCollisions`, `TestAtomicWriteTempAndHashVerification` (`core/engine/compat/rules_test.go`), and `TestE2E_FilenamesAndWarnings`. | **PASS** |
| **Secrets absent from git & logs** | `*.jks`, `*.keystore`, `key.properties`, `api.key`, `engine.key`, `*.p12`, `*.pfx`, `.env` ignored & absent from history. | Verified via `.gitignore` and `git log --all --name-only` (0 hits). | **PASS** |
| **Static analysis (`go vet`, `flutter analyze`)** | Zero vet or analyzer issues. | `go vet ./...` (`core/`) and `flutter analyze --no-pub --no-fatal-infos` (`app/`) pass with 0 issues. | **PASS** |
| **Vulnerability scan (`govulncheck`)** | Scan `core` and `tests` dependencies. | `.github/workflows/security.yml` runs `govulncheck ./...` on push/PR/weekly; **not run in offline sandbox** (no network / tool not preinstalled). Run locally with `govulncheck ./...`. | **NOT RUN (offline sandbox)** |
| **Checksummed downloads & no unsigned auto-update** | Releases publish `SHA256SUMS`; app contains no unsigned self-updater (`autoUpgradeIntervalH=0`, `--no-upgrade`). | Enforced in `core/engine/engine.go` and `.github/workflows/release.yml`. | **PASS** |
