#!/usr/bin/env bash
# macOS Application Bundle, Universal Binary & DMG Packaging Script
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
VERSION="${VERSION:-${DEFAULT_VERSION}}"
CORE_VERSION="${VERSION%%-*}"
CHANNEL="${CHANNEL:-stable}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/bin}"
COMMIT_SHA="${COMMIT_SHA:-$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

STAGE_ROOT="/tmp/tandem-macos-pkg"
BUNDLE_DIR="${STAGE_ROOT}/Tandem.app"
rm -rf "${STAGE_ROOT}"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS" \
         "${BUNDLE_DIR}/Contents/Helpers" \
         "${BUNDLE_DIR}/Contents/Resources" \
         "${OUT_DIR}"

LDFLAGS="-s -w -X main.version=${VERSION} -X main.commit=${COMMIT_SHA} -X main.buildDate=${BUILD_DATE} -X main.channel=${CHANNEL}"

# Build universal or architecture-specific tandemd binary
DAEMON_BIN="${STAGE_ROOT}/tandemd"
if command -v go >/dev/null 2>&1; then
    echo "Building tandemd ${VERSION} for darwin/amd64 and darwin/arm64..."
    (
        cd "${REPO_ROOT}/core"
        CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags "${LDFLAGS}" -o "${STAGE_ROOT}/tandemd_amd64" ./cmd/tandemd
        CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags "${LDFLAGS}" -o "${STAGE_ROOT}/tandemd_arm64" ./cmd/tandemd
    )
    if command -v lipo >/dev/null 2>&1; then
        lipo -create -output "${DAEMON_BIN}" "${STAGE_ROOT}/tandemd_amd64" "${STAGE_ROOT}/tandemd_arm64"
    else
        cp "${STAGE_ROOT}/tandemd_arm64" "${DAEMON_BIN}"
    fi
elif [[ -f "${REPO_ROOT}/bin/tandemd_darwin_arm64" ]]; then
    cp "${REPO_ROOT}/bin/tandemd_darwin_arm64" "${DAEMON_BIN}"
fi

# If a Flutter macOS .app bundle is supplied, wrap it and place tandemd in Contents/Helpers
if [[ -n "${FLUTTER_APP_PATH:-}" && -d "${FLUTTER_APP_PATH}" ]]; then
    echo "Integrating Flutter macOS app bundle from ${FLUTTER_APP_PATH}..."
    rm -rf "${BUNDLE_DIR}"
    cp -a "${FLUTTER_APP_PATH}" "${BUNDLE_DIR}"
    mkdir -p "${BUNDLE_DIR}/Contents/Helpers"
    cp "${DAEMON_BIN}" "${BUNDLE_DIR}/Contents/Helpers/tandemd"
    chmod 755 "${BUNDLE_DIR}/Contents/Helpers/tandemd"

    # Ensure Info.plist carries version & Local Network Privacy usage description
    python3 - "${BUNDLE_DIR}/Contents/Info.plist" "${CORE_VERSION}" "${VERSION}" << 'PYEOF'
import plistlib, sys
plist_path, short_ver, full_ver = sys.argv[1], sys.argv[2], sys.argv[3]
with open(plist_path, "rb") as f:
    data = plistlib.load(f)
data["CFBundleIdentifier"] = "com.tandem.sync"
data["CFBundleName"] = "Tandem"
data["CFBundleShortVersionString"] = short_ver
data["CFBundleVersion"] = full_ver
data["NSLocalNetworkUsageDescription"] = (
    "Tandem requires local network access to discover and securely synchronize files with nearby companion devices."
)
with open(plist_path, "wb") as f:
    plistlib.dump(data, f)
PYEOF
else
    if [[ -f "${DAEMON_BIN}" ]]; then
        cp "${DAEMON_BIN}" "${BUNDLE_DIR}/Contents/MacOS/tandemd"
        chmod 755 "${BUNDLE_DIR}/Contents/MacOS/tandemd"
    fi
    cat << EOF > "${BUNDLE_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>tandemd</string>
    <key>CFBundleIdentifier</key>
    <string>com.tandem.sync</string>
    <key>CFBundleName</key>
    <string>Tandem</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Tandem requires local network access to discover and securely synchronize files with nearby companion devices.</string>
</dict>
</plist>
EOF
fi

cp "${REPO_ROOT}/LICENSE" "${BUNDLE_DIR}/Contents/Resources/LICENSE"
cp "${REPO_ROOT}/THIRD_PARTY_NOTICES.md" "${BUNDLE_DIR}/Contents/Resources/THIRD_PARTY_NOTICES.md"

# Optional codesigning if identity is configured
if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]] && command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --options runtime --sign "${APPLE_SIGNING_IDENTITY}" "${BUNDLE_DIR}"
fi

TAR_PATH="${OUT_DIR}/tandem-${VERSION}-macos-universal.tar.gz"
tar -C "${STAGE_ROOT}" -czf "${TAR_PATH}" "Tandem.app"
echo "Created ${TAR_PATH}"

if command -v hdiutil >/dev/null 2>&1; then
    DMG_STAGE="${STAGE_ROOT}/dmg"
    mkdir -p "${DMG_STAGE}"
    cp -a "${BUNDLE_DIR}" "${DMG_STAGE}/"
    ln -sf /Applications "${DMG_STAGE}/Applications"
    DMG_PATH="${OUT_DIR}/tandem-${VERSION}-macos-universal.dmg"
    hdiutil create -volname "Tandem ${VERSION}" -srcfolder "${DMG_STAGE}" -ov -format UDZO "${DMG_PATH}"
    echo "Created ${DMG_PATH}"
fi
