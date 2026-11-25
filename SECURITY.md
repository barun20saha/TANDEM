# Security Policy

## Supported Versions

| Version | Supported | Notes |
|---|---|---|
| `0.3.x` (Stage A) | Yes | Linux desktop pre-release branch |
| `0.2.x` | No | Superseded (`v0.2.3` non-functional; upgrade recommended) |
| `0.1.x` | No | Initial alpha milestone |

## Scope
- **In scope:** `tandemd` loopback REST/SSE API (`127.0.0.1:8385`), API key/TLS certificate handling, BEP transport & pairing verification, path traversal / symlink / `.tandem-trash` safety, and OS installer/firewall scripts.
- **Out of scope:** Third-party community Syncthing relay infrastructure availability, physical device compromise, and issues on platforms explicitly marked untested in [docs/PLATFORM_STATUS.md](docs/PLATFORM_STATUS.md).

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
