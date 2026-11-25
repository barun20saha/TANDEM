#!/usr/bin/env bash
# Packages tandemd (and optional Flutter Linux bundle) into .deb and .tar.gz
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
VERSION="${VERSION:-0.2.0}"
ARCH="${ARCH:-amd64}"
CHANNEL="${CHANNEL:-stable}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/bin}"
COMMIT_SHA="${COMMIT_SHA:-$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

# Debian uses ~ for prerelease sorting if needed, keep clean filename
DEB_VERSION="${VERSION//-/\~}"
STAGE_DIR="/tmp/tandem-pkg/tandem_${VERSION}_linux_${ARCH}"
TAR_STAGE="/tmp/tandem-pkg/tandem-${VERSION}-linux-${ARCH}"

rm -rf "${STAGE_DIR}" "${TAR_STAGE}"
mkdir -p "${STAGE_DIR}/DEBIAN" \
         "${STAGE_DIR}/usr/bin" \
         "${STAGE_DIR}/usr/lib/systemd/user" \
         "${STAGE_DIR}/usr/share/doc/tandem" \
         "${TAR_STAGE}" \
         "${OUT_DIR}"

GO_CMD="go"
if command -v /tmp/tools/go/bin/go >/dev/null 2>&1; then
    GO_CMD="/tmp/tools/go/bin/go"
fi

LDFLAGS="-s -w -X main.version=${VERSION} -X main.commit=${COMMIT_SHA} -X main.buildDate=${BUILD_DATE} -X main.channel=${CHANNEL}"

if command -v "${GO_CMD}" >/dev/null 2>&1; then
    echo "Building tandemd ${VERSION} for linux/${ARCH}..."
    (
        cd "${REPO_ROOT}/core"
        CGO_ENABLED=0 GOOS=linux GOARCH="${ARCH}" \
            GOCACHE="${GOCACHE:-/tmp/gocache}" GOTOOLCHAIN="${GOTOOLCHAIN:-local}" \
            "${GO_CMD}" build -trimpath -ldflags "${LDFLAGS}" \
            -o "${STAGE_DIR}/usr/bin/tandemd" ./cmd/tandemd
    )
elif [[ -x "${REPO_ROOT}/bin/tandemd" && "${ARCH}" == "amd64" ]]; then
    echo "Go not found in PATH; reusing prebuilt bin/tandemd"
    cp "${REPO_ROOT}/bin/tandemd" "${STAGE_DIR}/usr/bin/tandemd"
else
    echo "error: Go toolchain not available to build linux/${ARCH}" >&2
    exit 1
fi
chmod 755 "${STAGE_DIR}/usr/bin/tandemd"

# Optional Flutter Linux UI bundle
if [[ -n "${FLUTTER_BUNDLE_DIR:-}" && -d "${FLUTTER_BUNDLE_DIR}" ]]; then
    echo "Embedding Flutter Linux UI bundle from ${FLUTTER_BUNDLE_DIR}..."
    mkdir -p "${STAGE_DIR}/opt/tandem" "${STAGE_DIR}/usr/share/applications"
    cp -a "${FLUTTER_BUNDLE_DIR}/." "${STAGE_DIR}/opt/tandem/"
    ln -sf /opt/tandem/tandem "${STAGE_DIR}/usr/bin/tandem"
    cat << 'EOF' > "${STAGE_DIR}/usr/share/applications/tandem.desktop"
[Desktop Entry]
Name=Tandem
Comment=Peer-to-peer file transfer and continuous folder sync
Exec=/usr/bin/tandem
Type=Application
Categories=Utility;Network;FileTransfer;
Terminal=false
EOF
    mkdir -p "${TAR_STAGE}/ui"
    cp -a "${FLUTTER_BUNDLE_DIR}/." "${TAR_STAGE}/ui/"
fi

# Systemd user unit
cat << 'EOF' > "${STAGE_DIR}/usr/lib/systemd/user/tandemd.service"
[Unit]
Description=Tandem Peer-to-Peer Sync Daemon
After=network.target

[Service]
ExecStart=/usr/bin/tandemd
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
EOF

# Docs & notices
cp "${REPO_ROOT}/LICENSE" "${STAGE_DIR}/usr/share/doc/tandem/LICENSE"
cp "${REPO_ROOT}/THIRD_PARTY_NOTICES.md" "${STAGE_DIR}/usr/share/doc/tandem/THIRD_PARTY_NOTICES.md"

# Debian control file
cat << EOF > "${STAGE_DIR}/DEBIAN/control"
Package: tandem
Version: ${DEB_VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Maintainer: Tandem Sync Team <support@tandem.local>
Homepage: https://github.com/barun20saha/TANDEM
Description: High-performance peer-to-peer file synchronization and transfer
 Tandem sends files without internet and keeps folders synchronized over
 direct encrypted peer-to-peer links.
EOF

chmod 755 "${STAGE_DIR}" "${STAGE_DIR}/DEBIAN"
DEB_PATH="${OUT_DIR}/tandem_${VERSION}_linux_${ARCH}.deb"
if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb --root-owner-group --build "${STAGE_DIR}" "${DEB_PATH}"
    echo "Created ${DEB_PATH}"
else
    echo "dpkg-deb not installed; staged Debian tree at ${STAGE_DIR}"
fi

# Portable .tar.gz archive
cp "${STAGE_DIR}/usr/bin/tandemd" "${TAR_STAGE}/tandemd"
cp "${STAGE_DIR}/usr/lib/systemd/user/tandemd.service" "${TAR_STAGE}/tandemd.service"
cp "${REPO_ROOT}/README.md" "${REPO_ROOT}/LICENSE" "${REPO_ROOT}/THIRD_PARTY_NOTICES.md" "${TAR_STAGE}/"
TAR_PATH="${OUT_DIR}/tandem-${VERSION}-linux-${ARCH}.tar.gz"
tar -C "$(dirname "${TAR_STAGE}")" -czf "${TAR_PATH}" "$(basename "${TAR_STAGE}")"
echo "Created ${TAR_PATH}"
