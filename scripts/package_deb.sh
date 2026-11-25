#!/usr/bin/env bash
# Packages tandemd (and optional Flutter Linux bundle) into .deb, .rpm, AppImage, and .tar.gz
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
VERSION="${VERSION:-0.2.3}"
CORE_VERSION="${VERSION%%-*}"
ARCH="${ARCH:-amd64}"
CHANNEL="${CHANNEL:-stable}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/bin}"
COMMIT_SHA="${COMMIT_SHA:-$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

# Debian uses ~ for prerelease sorting; RPM separates release tag
DEB_VERSION="${VERSION//-/\~}"
RPM_ARCH="x86_64"
if [[ "${ARCH}" == "arm64" ]]; then
    RPM_ARCH="aarch64"
fi

STAGE_DIR="/tmp/tandem-pkg/tandem_${VERSION}_linux_${ARCH}"
TAR_STAGE="/tmp/tandem-pkg/tandem-${VERSION}-linux-${ARCH}"
APPDIR="/tmp/tandem-pkg/Tandem-${ARCH}.AppDir"
RPM_ROOT="/tmp/tandem-pkg/rpmbuild-${ARCH}"

rm -rf "${STAGE_DIR}" "${TAR_STAGE}" "${APPDIR}" "${RPM_ROOT}"
mkdir -p "${STAGE_DIR}/DEBIAN" \
         "${STAGE_DIR}/usr/bin" \
         "${STAGE_DIR}/usr/lib/systemd/user" \
         "${STAGE_DIR}/usr/lib/firewalld/services" \
         "${STAGE_DIR}/etc/ufw/applications.d" \
         "${STAGE_DIR}/usr/share/doc/tandem" \
         "${STAGE_DIR}/usr/share/icons/hicolor/scalable/apps" \
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

# Bundle pinned Syncthing engine binary (required at runtime by tandemd)
ENGINE_BIN="${SYNCTHING_BIN:-}"
if [[ -z "${ENGINE_BIN}" ]]; then
    if [[ -x "/tmp/tools/syncthing" && "${ARCH}" == "amd64" ]]; then
        ENGINE_BIN="/tmp/tools/syncthing"
    elif command -v syncthing >/dev/null 2>&1 && [[ "${ARCH}" == "amd64" ]]; then
        ENGINE_BIN="$(command -v syncthing)"
    fi
fi
if [[ -n "${ENGINE_BIN}" && -f "${ENGINE_BIN}" ]]; then
    cp "${ENGINE_BIN}" "${STAGE_DIR}/usr/bin/syncthing"
    chmod 755 "${STAGE_DIR}/usr/bin/syncthing"
else
    echo "warning: SYNCTHING_BIN not found for linux/${ARCH}; package will require external syncthing" >&2
fi

# Systemd user unit, firewall hints (ufw & firewalld), & icon
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

cat << 'EOF' > "${STAGE_DIR}/etc/ufw/applications.d/tandem"
[Tandem]
title=Tandem Peer-to-Peer Sync
description=Direct BEP sync (TCP/UDP 22000) and local LAN discovery (UDP 21027)
ports=22000/tcp|22000/udp|21027/udp
EOF

cat << 'EOF' > "${STAGE_DIR}/usr/lib/firewalld/services/tandem.xml"
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Tandem</short>
  <description>Tandem Peer-to-Peer Sync and Local Discovery</description>
  <port protocol="tcp" port="22000"/>
  <port protocol="udp" port="22000"/>
  <port protocol="udp" port="21027"/>
</service>
EOF

cp "${REPO_ROOT}/design/tandem.svg" "${STAGE_DIR}/usr/share/icons/hicolor/scalable/apps/tandem.svg"
cp "${REPO_ROOT}/LICENSE" "${STAGE_DIR}/usr/share/doc/tandem/LICENSE"
cp "${REPO_ROOT}/THIRD_PARTY_NOTICES.md" "${STAGE_DIR}/usr/share/doc/tandem/THIRD_PARTY_NOTICES.md"

# Optional Flutter Linux UI bundle
HAS_UI="false"
if [[ -n "${FLUTTER_BUNDLE_DIR:-}" && -d "${FLUTTER_BUNDLE_DIR}" ]]; then
    HAS_UI="true"
    echo "Embedding Flutter Linux UI bundle from ${FLUTTER_BUNDLE_DIR}..."
    mkdir -p "${STAGE_DIR}/opt/tandem" "${STAGE_DIR}/usr/share/applications"
    cp -a "${FLUTTER_BUNDLE_DIR}/." "${STAGE_DIR}/opt/tandem/"
    ln -sf /opt/tandem/tandem "${STAGE_DIR}/usr/bin/tandem"
    cat << 'EOF' > "${STAGE_DIR}/usr/share/applications/tandem.desktop"
[Desktop Entry]
Name=Tandem
Comment=Peer-to-peer file transfer and continuous folder sync
Exec=/usr/bin/tandem
Icon=tandem
Type=Application
Categories=Utility;Network;FileTransfer;
Terminal=false
EOF
    mkdir -p "${TAR_STAGE}/ui"
    cp -a "${FLUTTER_BUNDLE_DIR}/." "${TAR_STAGE}/ui/"
fi

# 1. Debian (.deb) package
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

cat << 'EOF' > "${STAGE_DIR}/DEBIAN/postrm"
#!/usr/bin/env bash
set -e
# Remove program artifacts only; NEVER delete user synced folders or .tandem-trash.
if command -v ufw >/dev/null 2>&1; then
    ufw delete allow Tandem >/dev/null 2>&1 || true
fi
EOF
chmod 755 "${STAGE_DIR}/DEBIAN/postrm"

chmod 755 "${STAGE_DIR}" "${STAGE_DIR}/DEBIAN"
DEB_PATH="${OUT_DIR}/tandem_${VERSION}_linux_${ARCH}.deb"
if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb --root-owner-group --build "${STAGE_DIR}" "${DEB_PATH}"
    echo "Created ${DEB_PATH}"
fi

# 2. RPM (.rpm) package (native arch when rpmbuild is installed)
if command -v rpmbuild >/dev/null 2>&1 && [[ "${RPM_ARCH}" == "$(uname -m)" ]]; then
    mkdir -p "${RPM_ROOT}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    RPM_PAYLOAD="${RPM_ROOT}/SOURCES/tandem-${CORE_VERSION}"
    mkdir -p "${RPM_PAYLOAD}"
    cp -a "${STAGE_DIR}/usr" "${RPM_PAYLOAD}/"
    if [[ -d "${STAGE_DIR}/opt" ]]; then
        cp -a "${STAGE_DIR}/opt" "${RPM_PAYLOAD}/"
    fi
    cat << EOF > "${RPM_ROOT}/SPECS/tandem.spec"
Name:           tandem
Version:        ${CORE_VERSION}
Release:        1
Summary:        Peer-to-peer file transfer and continuous folder sync
License:        MIT
URL:            https://github.com/barun20saha/TANDEM
BuildArch:      ${RPM_ARCH}
AutoReqProv:    no

%description
Tandem sends files without internet and keeps folders synchronized over
direct encrypted peer-to-peer links.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a ${RPM_PAYLOAD}/* %{buildroot}/

%files
/usr/bin/tandemd
/usr/lib/systemd/user/tandemd.service
/usr/lib/firewalld/services/tandem.xml
/etc/ufw/applications.d/tandem
/usr/share/doc/tandem/LICENSE
/usr/share/doc/tandem/THIRD_PARTY_NOTICES.md
/usr/share/icons/hicolor/scalable/apps/tandem.svg
EOF
    if [[ -f "${STAGE_DIR}/usr/bin/syncthing" ]]; then
        echo "/usr/bin/syncthing" >> "${RPM_ROOT}/SPECS/tandem.spec"
    fi
    if [[ "${HAS_UI}" == "true" ]]; then
        cat << 'EOF' >> "${RPM_ROOT}/SPECS/tandem.spec"
/opt/tandem
/usr/bin/tandem
/usr/share/applications/tandem.desktop
EOF
    fi
    rpmbuild --define "_topdir ${RPM_ROOT}" --target "${RPM_ARCH}" -bb "${RPM_ROOT}/SPECS/tandem.spec" >/dev/null
    RPM_BUILT="$(find "${RPM_ROOT}/RPMS" -name '*.rpm' | head -n 1)"
    if [[ -n "${RPM_BUILT}" ]]; then
        RPM_OUT="${OUT_DIR}/tandem-${VERSION}-linux-${RPM_ARCH}.rpm"
        cp "${RPM_BUILT}" "${RPM_OUT}"
        echo "Created ${RPM_OUT}"
    fi
fi

# 3. AppImage single-file bundle (when appimagetool is available)
APPIMAGETOOL="${APPIMAGETOOL_BIN:-$(command -v appimagetool || true)}"
if [[ -n "${APPIMAGETOOL}" && "${ARCH}" == "amd64" ]]; then
    mkdir -p "${APPDIR}/usr/bin" \
             "${APPDIR}/usr/share/applications" \
             "${APPDIR}/usr/share/icons/hicolor/256x256/apps" \
             "${APPDIR}/usr/share/icons/hicolor/scalable/apps"
    cp "${STAGE_DIR}/usr/bin/tandemd" "${APPDIR}/usr/bin/tandemd"
    if [[ -f "${STAGE_DIR}/usr/bin/syncthing" ]]; then
        cp "${STAGE_DIR}/usr/bin/syncthing" "${APPDIR}/usr/bin/syncthing"
        chmod 755 "${APPDIR}/usr/bin/syncthing"
    fi
    cp "${REPO_ROOT}/design/tandem.png" "${APPDIR}/tandem.png"
    cp "${REPO_ROOT}/design/tandem.png" "${APPDIR}/.DirIcon"
    cp "${REPO_ROOT}/design/tandem.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/tandem.png"
    cp "${REPO_ROOT}/design/tandem.svg" "${APPDIR}/usr/share/icons/hicolor/scalable/apps/tandem.svg"
    if [[ "${HAS_UI}" == "true" ]]; then
        mkdir -p "${APPDIR}/opt/tandem"
        cp -a "${FLUTTER_BUNDLE_DIR}/." "${APPDIR}/opt/tandem/"
        ln -sf ../../opt/tandem/tandem "${APPDIR}/usr/bin/tandem"
        cat << 'EOF' > "${APPDIR}/AppRun"
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export PATH="${HERE}/usr/bin:${PATH}"
exec "${HERE}/opt/tandem/tandem" "$@"
EOF
        EXEC_NAME="tandem"
    else
        cat << 'EOF' > "${APPDIR}/AppRun"
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
exec "${HERE}/usr/bin/tandemd" "$@"
EOF
        EXEC_NAME="tandemd"
    fi
    chmod 755 "${APPDIR}/AppRun"
    cat << EOF > "${APPDIR}/tandem.desktop"
[Desktop Entry]
Name=Tandem
Comment=Peer-to-peer file transfer and continuous folder sync
Exec=${EXEC_NAME}
Icon=tandem
Type=Application
Categories=Utility;Network;FileTransfer;
Terminal=false
EOF
    cp "${APPDIR}/tandem.desktop" "${APPDIR}/usr/share/applications/tandem.desktop"
    APPIMAGE_OUT="${OUT_DIR}/tandem-${VERSION}-linux-${RPM_ARCH}.AppImage"
    ARCH="${RPM_ARCH}" APPIMAGE_EXTRACT_AND_RUN=1 "${APPIMAGETOOL}" --no-appstream "${APPDIR}" "${APPIMAGE_OUT}"
    chmod 755 "${APPIMAGE_OUT}"
    echo "Created ${APPIMAGE_OUT}"
fi

# 4. Portable .tar.gz archive
cp "${STAGE_DIR}/usr/bin/tandemd" "${TAR_STAGE}/tandemd"
if [[ -f "${STAGE_DIR}/usr/bin/syncthing" ]]; then
    cp "${STAGE_DIR}/usr/bin/syncthing" "${TAR_STAGE}/syncthing"
fi
cp "${STAGE_DIR}/usr/lib/systemd/user/tandemd.service" "${TAR_STAGE}/tandemd.service"
cp "${REPO_ROOT}/README.md" "${REPO_ROOT}/LICENSE" "${REPO_ROOT}/THIRD_PARTY_NOTICES.md" "${TAR_STAGE}/"
TAR_PATH="${OUT_DIR}/tandem-${VERSION}-linux-${ARCH}.tar.gz"
tar -C "$(dirname "${TAR_STAGE}")" -czf "${TAR_PATH}" "$(basename "${TAR_STAGE}")"
echo "Created ${TAR_PATH}"
