# Security Policy

## Supported Versions

| Version | Supported | Notes |
|---------|-----------|-------|
| `0.2.x` | Yes | Active multi-platform release branch |
| `0.1.x` | Security fixes only | Initial alpha milestone |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security issue in `tandemd`, the local loopback API (`127.0.0.1:8385`), TLS/BEP transport, pairing exchange, or OS platform adapters:

1. Use **GitHub Private Vulnerability Reporting** (`Security` tab -> `Report a vulnerability`) on `barun20saha/TANDEM`.
2. Include:
   - Affected platform(s) (Windows, macOS, Linux, Android) and version (`tandemd -version`)
   - Clear reproduction steps or proof-of-concept
   - Impact assessment (e.g., loopback auth bypass, path traversal, privilege escalation)
3. We aim to acknowledge reports within **48 hours** and provide a remediation timeline within **7 days**.

## Release Verification

All official releases published via GitHub Releases include:
- `SHA256SUMS.txt` covering all Windows, macOS, Linux, and Android artifacts
- `release-manifest.json` describing target platforms, architectures, and flavors
- GitHub Actions SLSA build provenance attestations (`gh attestation verify`)
