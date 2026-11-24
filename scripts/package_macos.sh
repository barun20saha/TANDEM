#!/usr/bin/env bash
# macOS Application Bundle & DMG Packaging Script (Section 4.4 & Phase 8)
set -euo pipefail

APP_NAME="Tandem"
BUNDLE_DIR="/tmp/Tandem.app"

echo "Assembling macOS app bundle at ${BUNDLE_DIR}..."
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

# Place daemon binary inside the bundle so privacy permissions attach to the app (Section 4.4)
cp "$(dirname "$0")/../bin/tandemd" "${BUNDLE_DIR}/Contents/MacOS/tandemd" || true

# Info.plist with mandatory Local Network Usage Description (macOS 15 Sequoia requirement)
cat << 'EOF' > "${BUNDLE_DIR}/Contents/Info.plist"
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
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Tandem requires local network access to discover and securely synchronize files with nearby companion devices.</string>
</dict>
</plist>
EOF

echo "macOS bundle assembled. Ready for codesign --deep and notarytool."
