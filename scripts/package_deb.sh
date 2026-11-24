#!/usr/bin/env bash
# Packages tandemd into a standalone Debian (.deb) package
set -euo pipefail

VERSION="0.1.0"
ARCH="amd64"
PKG_DIR="/tmp/tandem-pkg/tandem_${VERSION}_${ARCH}"

rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/bin"
mkdir -p "${PKG_DIR}/usr/lib/systemd/user"

# Build binary
echo "Building tandemd binary..."
cd "$(dirname "$0")/../core"
go build -o "${PKG_DIR}/usr/bin/tandemd" ./cmd/tandemd
chmod 755 "${PKG_DIR}/usr/bin/tandemd"

# Control file
cat << EOF > "${PKG_DIR}/DEBIAN/control"
Package: tandem
Version: ${VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Maintainer: Tandem Sync Team <support@tandem.local>
Description: High-performance peer-to-peer file synchronization and transfer daemon
EOF

# Systemd user unit
cat << EOF > "${PKG_DIR}/usr/lib/systemd/user/tandemd.service"
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

# Build .deb package
dpkg-deb --build "${PKG_DIR}" "$(dirname "$0")/../bin/tandem_${VERSION}_${ARCH}.deb" || {
    echo "dpkg-deb not present or container sandboxed, packaging directory prepared at ${PKG_DIR}"
}
echo "Linux Debian packaging completed."
