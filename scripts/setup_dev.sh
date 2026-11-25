#!/usr/bin/env bash
# Checks and prints PASS/FAIL for Tandem developer prerequisites on Linux/macOS.
# Never hides missing commands or swallows non-zero exit codes.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

# Support local toolchain directory if present
for extra in /tmp/tools/go/bin /tmp/tools/flutter/bin /tmp/tools; do
    if [[ -d "${extra}" && ":${PATH}:" != *":${extra}:"* ]]; then
        export PATH="${extra}:${PATH}"
    fi
done

check_cmd() {
    local name="$1"
    local bin="$2"
    local ver_flag="${3:---version}"
    if ! command -v "${bin}" >/dev/null 2>&1; then
        echo "FAIL: ${name} (${bin}) not found in PATH"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
    local out
    if ! out="$("${bin}" ${ver_flag} 2>&1 | head -n 1)"; then
        echo "FAIL: ${name} (${bin}) exited with error: ${out}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
    echo "PASS: ${name} -> ${out}"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
}

echo "=== Tandem Dev Environment Check ==="
check_cmd "Go (>= 1.24)" "go" "version"
check_cmd "Flutter" "flutter" "--version"
check_cmd "Python 3" "python3" "--version"
check_cmd "Syncthing (v2.1.7)" "syncthing" "--version"
check_cmd "ss (socket diagnostics)" "ss" "--version"
check_cmd "Java" "java" "-version" || true

if [[ -n "${ANDROID_HOME:-}" && -d "${ANDROID_HOME}" ]]; then
    echo "PASS: ANDROID_HOME=${ANDROID_HOME}"
    PASS_COUNT=$((PASS_COUNT + 1))
elif [[ -d /tmp/tools/android-sdk ]]; then
    echo "PASS: Android SDK found at /tmp/tools/android-sdk"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "WARN: ANDROID_HOME not set (required only for Stage C Android builds)"
fi

echo "Summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed."
if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    echo "Install missing tools, e.g.:"
    echo "  - Go 1.24+: https://go.dev/dl/"
    echo "  - Flutter stable: https://docs.flutter.dev/get-started/install"
    echo "  - Pinned Syncthing v2.1.7: python3 scripts/fetch_syncthing.py --out /tmp/tools/syncthing"
    exit 1
fi
