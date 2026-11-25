#!/usr/bin/env python3
"""
Generates SHA256SUMS.txt and release-manifest.json for packaged release artifacts.
"""

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def classify_artifact(name: str) -> dict:
    lower = name.lower()
    if "windows" in lower or lower.endswith(".exe") or lower.endswith(".msi"):
        platform = "windows"
    elif "macos" in lower or "darwin" in lower or lower.endswith(".dmg"):
        platform = "macos"
    elif "android" in lower or lower.endswith(".apk") or lower.endswith(".aab"):
        platform = "android"
    else:
        platform = "linux"

    arch = "universal"
    for candidate in ("amd64", "x86_64", "arm64", "aarch64", "sideload", "play"):
        if candidate in lower:
            arch = candidate
            break

    kind = "archive"
    if lower.endswith("-setup.exe"):
        kind = "installer"
    elif lower.endswith(".dmg"):
        kind = "dmg"
    elif lower.endswith(".appimage"):
        kind = "appimage"
    elif lower.endswith(".deb"):
        kind = "deb"
    elif lower.endswith(".rpm"):
        kind = "rpm"
    elif lower.endswith(".apk"):
        kind = "apk"
    elif lower.endswith(".aab"):
        kind = "aab"

    return {"name": name, "platform": platform, "variant": arch, "kind": kind}


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate release checksums and manifest.")
    parser.add_argument("--dist-dir", required=True, help="Directory with release artifacts")
    parser.add_argument("--version", required=True, help="Release version (without leading v)")
    parser.add_argument("--tag", required=True, help="Git tag (e.g. v0.2.0)")
    parser.add_argument("--commit", default="unknown", help="Git commit SHA")
    parser.add_argument("--channel", default="stable", help="Release channel")
    args = parser.parse_args()

    dist_dir = os.path.abspath(args.dist_dir)
    files = sorted(
        f
        for f in os.listdir(dist_dir)
        if os.path.isfile(os.path.join(dist_dir, f))
        and f not in ("SHA256SUMS.txt", "release-manifest.json")
    )

    checksum_lines = []
    artifacts = []
    for name in files:
        full_path = os.path.join(dist_dir, name)
        digest = sha256_file(full_path)
        size = os.path.getsize(full_path)
        checksum_lines.append(f"{digest}  {name}")
        meta = classify_artifact(name)
        meta["sha256"] = digest
        meta["sizeBytes"] = size
        artifacts.append(meta)

    with open(os.path.join(dist_dir, "SHA256SUMS.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(checksum_lines) + ("\n" if checksum_lines else ""))

    manifest = {
        "schemaVersion": 1,
        "product": "Tandem",
        "version": args.version,
        "tag": args.tag,
        "channel": args.channel,
        "commit": args.commit,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "artifacts": artifacts,
    }
    with open(os.path.join(dist_dir, "release-manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    print(f"Generated SHA256SUMS.txt and release-manifest.json for {len(artifacts)} artifacts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
