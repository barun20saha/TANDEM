# Contributing to Tandem

Thank you for helping build Tandem. We welcome bug reports, documentation improvements, platform adapter fixes, and feature pull requests.

## Development Setup

### Prerequisites
- **Go 1.24+** (for `core/` and `tests/`)
- **Flutter (stable)** (for `app/`)
- **Python 3.10+** (for `design/generate_tokens.py`, `design/audit.py`, and `scripts/bump_version.py`)

### Running Local Verification
Before opening a pull request, verify all suites pass:

```bash
# 1. Core Go unit and PAL contract tests
cd core && CGO_ENABLED=0 go test -v ./...

# 2. Chaos & safety tests
cd tests/chaos && CGO_ENABLED=0 go test -v .

# 3. Design token coverage audit (must report 0 violations and 100.0%)
python3 design/audit.py

# 4. Flutter static analysis and widget tests
cd app && flutter pub get && flutter analyze && flutter test
```

## Pull Request & Commit Guidelines

1. **Conventional Commits:** Use prefixes such as `feat:`, `fix:`, `ci:`, `docs:`, `refactor:`, `test:`, or `chore:` (e.g., `fix(pal_linux): handle missing ufw binary`).
2. **Design Tokens:** Never hardcode hex colors or arbitrary spacing in `app/lib/` outside `app/lib/theme/tokens.dart`. Edit `design/tokens.json` and run `python3 design/generate_tokens.py`.
3. **Cross-OS Compatibility:** Ensure changes respect platform differences documented in `docs/PLATFORM_STATUS.md` and `docs/DECISIONS.md`.
4. **Changelog:** Update the `[Unreleased]` section of `CHANGELOG.md` for user-visible changes.
5. **Small, Focused PRs:** Fill out `.github/PULL_REQUEST_TEMPLATE.md` completely.

## Release Process (Maintainers)

Releases follow Semantic Versioning (`vMAJOR.MINOR.PATCH[-PRERELEASE]`):

```bash
# 1. Bump and synchronize VERSION across Go, Flutter, and packaging scripts
python3 scripts/bump_version.py 0.3.0

# 2. Update CHANGELOG.md and commit
git add -A && git commit -m "chore(release): prepare v0.3.0"

# 3. Create an annotated tag and push to trigger multi-OS GitHub Release builds
git tag -a v0.3.0 -m "Release v0.3.0"
git push origin main --tags
```
