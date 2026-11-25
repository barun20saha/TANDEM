#!/usr/bin/env python3
"""
Synchronizes the Tandem version across all project manifests, daemon defaults,
and packaging scripts from the root VERSION file (or an explicit SemVer argument).

Usage:
  python3 scripts/bump_version.py                # Sync files to current VERSION
  python3 scripts/bump_version.py 0.3.0          # Bump to 0.3.0 and sync
  python3 scripts/bump_version.py 0.3.0-beta.1   # Bump to pre-release and sync
"""

import argparse
import os
import re
import sys

SEMVER_RE = re.compile(
    r"^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)"
    r"(?:-(?P<prerelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
    r"(?:\+(?P<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
)


def compute_version_code(major: int, minor: int, patch: int) -> int:
    """Computes monotonic Android/Flutter build number from SemVer."""
    return major * 10000 + minor * 100 + patch


def replace_once(path: str, pattern: str, replacement: str) -> None:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    new_content, count = re.subn(pattern, replacement, content, flags=re.MULTILINE)
    if count == 0:
        raise RuntimeError(f"Pattern {pattern!r} not found in {path}")
    if new_content != content:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync or bump Tandem version.")
    parser.add_argument("version", nargs="?", help="New SemVer version (optional)")
    args = parser.parse_args()

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    version_file = os.path.join(repo_root, "VERSION")

    if args.version:
        version = args.version.lstrip("v").strip()
    else:
        with open(version_file, "r", encoding="utf-8") as f:
            version = f.read().strip()

    match = SEMVER_RE.match(version)
    if not match:
        print(f"error: invalid SemVer version {version!r}", file=sys.stderr)
        return 1

    major = int(match.group("major"))
    minor = int(match.group("minor"))
    patch = int(match.group("patch"))
    prerelease = match.group("prerelease")
    core_semver = f"{major}.{minor}.{patch}"
    build_number = max(1, compute_version_code(major, minor, patch))
    channel = "stable"
    if prerelease:
        channel = prerelease.split(".")[0]

    with open(version_file, "w", encoding="utf-8") as f:
        f.write(version + "\n")

    # 1. Flutter app/pubspec.yaml
    pubspec_version = f"{version}+{build_number}"
    replace_once(
        os.path.join(repo_root, "app", "pubspec.yaml"),
        r"^version:\s+.*$",
        f"version: {pubspec_version}",
    )

    # 2. Go daemon default build variables
    replace_once(
        os.path.join(repo_root, "core", "cmd", "tandemd", "main.go"),
        r'(\tversion\s*=\s*)"[^"]*"',
        rf'\1"{version}"',
    )
    replace_once(
        os.path.join(repo_root, "core", "cmd", "tandemd", "main.go"),
        r'(\tchannel\s*=\s*)"[^"]*"',
        rf'\1"{channel}"',
    )

    # 3. API server fallback version
    replace_once(
        os.path.join(repo_root, "core", "api", "server.go"),
        r'(cfg\.Version\s*=\s*)"[^"]*"',
        rf'\1"{version}"',
    )

    # 4. Packaging scripts fallback versions
    replace_once(
        os.path.join(repo_root, "scripts", "package_deb.sh"),
        r'^VERSION="\$\{VERSION:-[^}]*\}"$|^VERSION="[^"]*"$',
        f'VERSION="${{VERSION:-{version}}}"',
    )
    replace_once(
        os.path.join(repo_root, "scripts", "package_macos.sh"),
        r'(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*(</string>)',
        rf"\g<1>{core_semver}\g<2>",
    )
    replace_once(
        os.path.join(repo_root, "scripts", "package_windows.ps1"),
        r'(\[string\]\$Version\s*=\s*)"[^"]*"',
        rf'\1"{version}"',
    )

    print(
        f"Synchronized version={version} (core={core_semver}, "
        f"build={build_number}, channel={channel})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
