#!/usr/bin/env bash
# Packages Tandem for Android in dual distribution flavors per docs/DECISIONS.md (D5):
#   - sideload: includes MANAGE_EXTERNAL_STORAGE for unrestricted folder/camera sync
#   - play: removes MANAGE_EXTERNAL_STORAGE for Google Play SAF/MediaStore compliance
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
VERSION="${VERSION:-${DEFAULT_VERSION}}"
CORE_VERSION="${VERSION%%-*}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/bin}"
APP_DIR="${REPO_ROOT}/app"

mkdir -p "${OUT_DIR}"

if ! command -v flutter >/dev/null 2>&1; then
    echo "error: flutter SDK is required to build Android artifacts" >&2
    exit 1
fi

# Compute monotonic Android versionCode from SemVer
IFS='.' read -r MAJOR MINOR PATCH <<< "${CORE_VERSION}"
VERSION_CODE=$(( MAJOR * 10000 + MINOR * 100 + PATCH ))
if [[ "${VERSION_CODE}" -lt 1 ]]; then
    VERSION_CODE=1
fi

# Ensure Flutter Android runner scaffold exists without clobbering custom Kotlin/Manifest files
if [[ ! -f "${APP_DIR}/android/build.gradle" && ! -f "${APP_DIR}/android/build.gradle.kts" ]]; then
    echo "Initializing Flutter Android Gradle scaffold..."
    BACKUP_DIR="/tmp/tandem-android-backup"
    rm -rf "${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
    cp -a "${APP_DIR}/android/app/src" "${BACKUP_DIR}/src"

    (
        cd "${APP_DIR}"
        flutter create --platforms=android --org com.tandem --project-name tandem .
    )

    # Restore custom Tandem Android sources & manifests while preserving generated res/
    if [[ -d "${APP_DIR}/android/app/src/main/res" && ! -d "${BACKUP_DIR}/src/main/res" ]]; then
        cp -a "${APP_DIR}/android/app/src/main/res" "${BACKUP_DIR}/src/main/res"
    fi
    rm -rf "${APP_DIR}/android/app/src"
    cp -a "${BACKUP_DIR}/src" "${APP_DIR}/android/app/src"
fi

# Ensure Gradle app configuration uses com.tandem.sync and sideload/play productFlavors
python3 - "${APP_DIR}/android/app" << 'PYEOF'
import os, re, sys

app_android_dir = sys.argv[1]
candidates = [
    os.path.join(app_android_dir, "build.gradle.kts"),
    os.path.join(app_android_dir, "build.gradle"),
]
target = next((p for p in candidates if os.path.exists(p)), None)
if not target:
    raise SystemExit("No build.gradle or build.gradle.kts found")

with open(target, "r", encoding="utf-8") as f:
    text = f.read()

is_kts = target.endswith(".kts")
text = re.sub(r'namespace\s*=?\s*"[^"]*"', 'namespace = "com.tandem.sync"' if is_kts else 'namespace "com.tandem.sync"', text)
text = re.sub(r'applicationId\s*=?\s*"[^"]*"', 'applicationId = "com.tandem.sync"' if is_kts else 'applicationId "com.tandem.sync"', text)
text = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24', text)
text = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24', text)
text = re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion', 'targetSdk = 35', text)
text = re.sub(r'targetSdkVersion\s+flutter\.targetSdkVersion', 'targetSdkVersion 35', text)

# Require release keystore from key.properties for release builds (never fall back to debug key)
if "signingConfigs" not in text:
    if is_kts:
        signing_block = """
    val keystorePropsFile = rootProject.file("key.properties")
    val keystoreProps = java.util.Properties()
    if (keystorePropsFile.exists()) {
        keystoreProps.load(java.io.FileInputStream(keystorePropsFile))
    }
    signingConfigs {
        create("release") {
            if (!keystorePropsFile.exists()) {
                throw GradleException("Release signing requires android/key.properties (never fall back to debug key).")
            }
            keyAlias = keystoreProps.getProperty("keyAlias")
            keyPassword = keystoreProps.getProperty("keyPassword")
            storeFile = file(keystoreProps.getProperty("storeFile"))
            storePassword = keystoreProps.getProperty("storePassword")
        }
    }
"""
        text = re.sub(r'(buildTypes\s*\{)', signing_block + r'\n    \1', text, count=1)
        text = text.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
    else:
        signing_block = """
    def keystorePropsFile = rootProject.file("key.properties")
    def keystoreProps = new Properties()
    if (keystorePropsFile.exists()) {
        keystoreProps.load(new FileInputStream(keystorePropsFile))
    }
    signingConfigs {
        release {
            if (!keystorePropsFile.exists()) {
                throw new GradleException("Release signing requires android/key.properties (never fall back to debug key).")
            }
            keyAlias keystoreProps["keyAlias"]
            keyPassword keystoreProps["keyPassword"]
            storeFile file(keystoreProps["storeFile"])
            storePassword keystoreProps["storePassword"]
        }
    }
"""
        text = re.sub(r'(buildTypes\s*\{)', signing_block + r'\n    \1', text, count=1)
        text = text.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.release')

if "flavorDimensions" not in text:
    if is_kts:
        flavor_block = """
    flavorDimensions += "distribution"
    productFlavors {
        create("sideload") {
            dimension = "distribution"
        }
        create("play") {
            dimension = "distribution"
            applicationIdSuffix = ".play"
        }
    }
"""
    else:
        flavor_block = """
    flavorDimensions "distribution"
    productFlavors {
        sideload {
            dimension "distribution"
        }
        play {
            dimension "distribution"
            applicationIdSuffix ".play"
        }
    }
"""
    text = re.sub(r'(buildTypes\s*\{)', flavor_block + r'\n    \1', text, count=1)

if "androidx.core:core-ktx" not in text:
    if is_kts:
        deps_block = """
dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.annotation:annotation:1.8.2")
}
"""
    else:
        deps_block = """
dependencies {
    implementation "androidx.core:core-ktx:1.13.1"
    implementation "androidx.annotation:annotation:1.8.2"
}
"""
    text = text.rstrip() + "\n" + deps_block

with open(target, "w", encoding="utf-8") as f:
    f.write(text)
print(f"Configured {target}")
PYEOF

# Cross-compile native Go libtandemd.so for Android ABIs if NDK is present
if [[ -z "${ANDROID_HOME:-}" && -d /usr/local/lib/android/sdk ]]; then
    export ANDROID_HOME="/usr/local/lib/android/sdk"
fi
NDK_DIR="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${ANDROID_NDK_LATEST_HOME:-}}}"
if [[ -z "${NDK_DIR}" && -n "${ANDROID_HOME:-}" && -d "${ANDROID_HOME}/ndk" ]]; then
    NDK_DIR="$(ls -d "${ANDROID_HOME}/ndk/"* 2>/dev/null | sort -V | tail -n 1 || true)"
fi

if [[ -n "${NDK_DIR}" && -d "${NDK_DIR}" ]] && command -v go >/dev/null 2>&1; then
    HOST_TAG="$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64"
    TOOLCHAIN="${NDK_DIR}/toolchains/llvm/prebuilt/${HOST_TAG}/bin"
    if [[ -d "${TOOLCHAIN}" ]]; then
        build_abi() {
            local abi="$1" goarch="$2" cc="$3" goarm="${4:-}"
            local jni_dir="${APP_DIR}/android/app/src/main/jniLibs/${abi}"
            mkdir -p "${jni_dir}"
            echo "Building libtandemd.so for ${abi}..."
            (
                cd "${REPO_ROOT}/core"
                CC="${TOOLCHAIN}/${cc}" CGO_ENABLED=1 GOOS=android GOARCH="${goarch}" GOARM="${goarm}" \
                    go build -buildmode=c-shared -trimpath -ldflags="-s -w" \
                    -o "${jni_dir}/libtandemd.so" ./cmd/tandemd_android
            )
            rm -f "${jni_dir}/libtandemd.h"
        }
        build_abi "arm64-v8a" "arm64" "aarch64-linux-android24-clang"
        build_abi "armeabi-v7a" "arm" "armv7a-linux-androideabi24-clang" "7"
        build_abi "x86_64" "amd64" "x86_64-linux-android24-clang"
    fi
else
    echo "Note: Android NDK not configured; building Flutter APK/AAB without native CGO libtandemd.so"
fi

# Build Flutter Android variants
(
    cd "${APP_DIR}"
    flutter pub get
    flutter build apk --release --flavor sideload --build-name="${CORE_VERSION}" --build-number="${VERSION_CODE}"
    flutter build apk --release --flavor play --build-name="${CORE_VERSION}" --build-number="${VERSION_CODE}"
    flutter build appbundle --release --flavor play --build-name="${CORE_VERSION}" --build-number="${VERSION_CODE}"
)

cp "${APP_DIR}/build/app/outputs/flutter-apk/app-sideload-release.apk" "${OUT_DIR}/tandem-${VERSION}-android-sideload.apk"
cp "${APP_DIR}/build/app/outputs/flutter-apk/app-play-release.apk" "${OUT_DIR}/tandem-${VERSION}-android-play.apk"
cp "${APP_DIR}/build/app/outputs/bundle/playRelease/app-play-release.aab" "${OUT_DIR}/tandem-${VERSION}-android-play.aab"

echo "Android packages created in ${OUT_DIR}"
