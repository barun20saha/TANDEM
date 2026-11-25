## Summary

<!-- Describe what this PR changes and why. -->

## Affected Platforms

- [ ] Windows
- [ ] macOS
- [ ] Linux
- [ ] Android
- [ ] Cross-platform / CI / Docs

## Verification Checklist

- [ ] `cd core && go test ./...` passes
- [ ] `cd tests/chaos && go test .` passes
- [ ] `python3 design/audit.py` reports 0 hard-coded color violations and 100.0% score
- [ ] `cd app && flutter analyze && flutter test` passes
- [ ] `CHANGELOG.md` updated under `[Unreleased]` (if user-facing)
- [ ] Platform constraints in `docs/PLATFORM_STATUS.md` and `docs/DECISIONS.md` respected
