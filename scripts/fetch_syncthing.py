#!/usr/bin/env python3
"""
Downloads and SHA-256 verifies the pinned Syncthing v2.1.7 binary for the
requested OS/architecture.
"""

import argparse
import hashlib
import os
import platform
import shutil
import tarfile
import tempfile
import urllib.request
import zipfile

SYNCTHING_VERSION = "v2.1.7"

ASSETS = {
    ("linux", "amd64"): (
        f"https://github.com/syncthing/syncthing/releases/download/{SYNCTHING_VERSION}/syncthing-linux-amd64-{SYNCTHING_VERSION}.tar.gz",
        "2edc416e7ed136b7c858ed5f3f02a3b8316589605e54c380228ceea7acbf0142",
        "syncthing",
    ),
    ("linux", "arm64"): (
        f"https://github.com/syncthing/syncthing/releases/download/{SYNCTHING_VERSION}/syncthing-linux-arm64-{SYNCTHING_VERSION}.tar.gz",
        "48e456690cd2b97e7d26b02b5ac35f62a3b36172267b144cfeaf02c993ab955c",
        "syncthing",
    ),
    ("darwin", "universal"): (
        f"https://github.com/syncthing/syncthing/releases/download/{SYNCTHING_VERSION}/syncthing-macos-universal-{SYNCTHING_VERSION}.zip",
        "a98fb709c79412e5586c81a1586bfb256b6e5a97b067ddf7447155bcdf6aac3f",
        "syncthing",
    ),
    ("darwin", "amd64"): (
        f"https://github.com/syncthing/syncthing/releases/download/{SYNCTHING_VERSION}/syncthing-macos-amd64-{SYNCTHING_VERSION}.zip",
        "b8be90176d0f24daebae7b5aaddac52ebfae395df6d99f5e0e54656db00868cb",
        "syncthing",
    ),
    ("darwin", "arm64"): (
        f"https://github.com/syncthing/syncthing/releases/download/{SYNCTHING_VERSION}/syncthing-macos-arm64-{SYNCTHING_VERSION}.zip",
        "2df075b463231a307c91da657157beaed06383a941ba7ea04d33d536e3c4af38",
        "syncthing",
    ),
    ("windows", "amd64"): (
        f"https://github.com/syncthing/syncthing/releases/download/{SYNCTHING_VERSION}/syncthing-windows-amd64-{SYNCTHING_VERSION}.zip",
        "3ce7da770f546a8d02b65b2e7ee31f2a3b8b7c3f990ede045590cca4172ecfe1",
        "syncthing.exe",
    ),
    ("windows", "arm64"): (
        f"https://github.com/syncthing/syncthing/releases/download/{SYNCTHING_VERSION}/syncthing-windows-arm64-{SYNCTHING_VERSION}.zip",
        "d535ffd611b3af223de64bc5dfc60c378881eb13d5c8ecb1431b7407094c15ff",
        "syncthing.exe",
    ),
}


def detect_platform():
    sys_name = platform.system().lower()
    if sys_name == "darwin":
        os_name = "darwin"
    elif sys_name == "windows":
        os_name = "windows"
    else:
        os_name = "linux"

    mach = platform.machine().lower()
    if mach in ("x86_64", "amd64"):
        arch = "amd64"
    elif mach in ("arm64", "aarch64"):
        arch = "arm64"
    else:
        arch = mach
    return os_name, arch


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    default_os, default_arch = detect_platform()
    parser = argparse.ArgumentParser(description="Fetch pinned Syncthing binary.")
    parser.add_argument("--os", default=default_os, choices=["linux", "darwin", "windows"])
    parser.add_argument("--arch", default=default_arch, choices=["amd64", "arm64", "universal"])
    parser.add_argument("--out", required=True, help="Destination binary path (or directory)")
    args = parser.parse_args()

    key = (args.os, args.arch)
    if key not in ASSETS:
        raise SystemExit(f"Unsupported Syncthing target: {key}")

    url, expected_sha, bin_name = ASSETS[key]
    out_path = os.path.abspath(args.out)
    if os.path.isdir(out_path) or out_path.endswith(os.sep):
        os.makedirs(out_path, exist_ok=True)
        out_path = os.path.join(out_path, bin_name)
    else:
        os.makedirs(os.path.dirname(out_path), exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        archive = os.path.join(tmp, os.path.basename(url))
        print(f"Downloading {url}...")
        urllib.request.urlretrieve(url, archive)
        actual_sha = sha256_file(archive)
        if actual_sha != expected_sha:
            raise RuntimeError(f"SHA256 mismatch: expected {expected_sha}, got {actual_sha}")
        print(f"SHA256 verified: {actual_sha}")

        if archive.endswith(".tar.gz"):
            with tarfile.open(archive, "r:gz") as tf:
                member = next(m for m in tf.getmembers() if m.name.endswith("/" + bin_name))
                with tf.extractfile(member) as src, open(out_path, "wb") as dst:
                    shutil.copyfileobj(src, dst)
        else:
            with zipfile.ZipFile(archive, "r") as zf:
                member = next(n for n in zf.namelist() if n.endswith("/" + bin_name))
                with zf.open(member) as src, open(out_path, "wb") as dst:
                    shutil.copyfileobj(src, dst)

    os.chmod(out_path, 0o755)
    print(f"Installed pinned Syncthing {SYNCTHING_VERSION} at {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
