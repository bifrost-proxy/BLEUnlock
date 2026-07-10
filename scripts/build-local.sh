#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/local-clt"
APP_DIR="${BUILD_DIR}/BLEUnlockLocal.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
EXECUTABLE="${MACOS_DIR}/BLEUnlockLocal"
LOG_FILE="${BUILD_DIR}/launch.log"
BUNDLE_ID="com.bifrost-proxy.BLEUnlock.LocalDev"
MODE="build"
SMOKE_SECONDS="${BLEUNLOCK_SMOKE_SECONDS:-5}"
DMG_PATH="${BUILD_DIR}/BLEUnlockLocal.dmg"
CHECKSUM_PATH="${DMG_PATH}.sha256"
MOUNT_DIR="${BUILD_DIR}/mounted-dmg"
MOUNT_ATTACHED=0
local_pid=""

usage() {
  cat <<'EOF'
Build a launchable BLEUnlock development app with Command Line Tools only.

Usage:
  scripts/build-local.sh                Build only
  scripts/build-local.sh --run          Build and keep the app running
  scripts/build-local.sh --smoke-test   Build, run briefly, verify, then stop
  scripts/build-local.sh --package      Build and verify a local DMG
  scripts/build-local.sh --verify       Build, smoke-test, package, and verify

The output is build/local-clt/BLEUnlockLocal.app. The local app uses an
isolated bundle identifier and disables automatic lock/unlock before launch.
It is intended for local compile/start checks, not release packaging.
EOF
}

cleanup() {
  if [[ -n "${local_pid}" ]] && kill -0 "${local_pid}" 2>/dev/null; then
    kill -TERM "${local_pid}" 2>/dev/null || true
    wait "${local_pid}" 2>/dev/null || true
  fi
  if [[ "${MOUNT_ATTACHED}" -eq 1 ]]; then
    hdiutil detach "${MOUNT_DIR}" -quiet >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run)
      MODE="run"
      ;;
    --smoke-test)
      MODE="smoke"
      ;;
    --package)
      MODE="package"
      ;;
    --verify)
      MODE="verify"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! [[ "${SMOKE_SECONDS}" =~ ^[0-9]+$ ]] || [[ "${SMOKE_SECONDS}" -lt 1 ]]; then
  echo "BLEUNLOCK_SMOKE_SECONDS must be a positive integer." >&2
  exit 2
fi

for command in xcrun uname plutil codesign hdiutil shasum; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command not found: ${command}" >&2
    exit 1
  fi
done

SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
OBJECT_DIR="${BUILD_DIR}/objects"

rm -rf "${BUILD_DIR}"
mkdir -p "${OBJECT_DIR}" "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "Building BLEUnlockLocal with ${ARCH} Command Line Tools SDK: ${SDKROOT}"

xcrun --sdk macosx clang \
  -arch "${ARCH}" \
  -mmacosx-version-min=10.13 \
  -include CoreFoundation/CoreFoundation.h \
  -I "${ROOT_DIR}/BLEUnlock" \
  -c "${ROOT_DIR}/BLEUnlock/lowlevel.c" \
  -o "${OBJECT_DIR}/lowlevel.o"

xcrun --sdk macosx swiftc \
  -target "${ARCH}-apple-macosx10.13" \
  -sdk "${SDKROOT}" \
  -Onone \
  -g \
  -D BLEUNLOCK_LOCAL_MAIN \
  -module-name BLEUnlock \
  -import-objc-header "${ROOT_DIR}/BLEUnlock/BLEUnlock-Bridging-Header.h" \
  "${ROOT_DIR}/BLEUnlock/AppDelegate.swift" \
  "${ROOT_DIR}/BLEUnlock/BLE.swift" \
  "${ROOT_DIR}/BLEUnlock/LEDeviceInfo.swift" \
  "${ROOT_DIR}/BLEUnlock/appleDeviceNames.swift" \
  "${ROOT_DIR}/BLEUnlock/checkUpdate.swift" \
  "${ROOT_DIR}/BLEUnlock/AboutBox.swift" \
  "${ROOT_DIR}/scripts/LocalMain.swift" \
  "${OBJECT_DIR}/lowlevel.o" \
  -F "${SDKROOT}/System/Library/PrivateFrameworks" \
  -framework Cocoa \
  -framework CoreBluetooth \
  -framework IOBluetooth \
  -framework ServiceManagement \
  -framework UserNotifications \
  -framework IOKit \
  -framework MediaRemote \
  -framework login \
  -lsqlite3 \
  -o "${EXECUTABLE}"

cp "${ROOT_DIR}/BLEUnlock/Info.plist" "${CONTENTS_DIR}/Info.plist"
plutil -replace CFBundleExecutable -string BLEUnlockLocal "${CONTENTS_DIR}/Info.plist"
plutil -replace CFBundleIdentifier -string "${BUNDLE_ID}" "${CONTENTS_DIR}/Info.plist"
plutil -replace CFBundleName -string "BLEUnlock Local" "${CONTENTS_DIR}/Info.plist"
plutil -replace CFBundleShortVersionString -string "0.0.0-local" "${CONTENTS_DIR}/Info.plist"
plutil -replace CFBundleVersion -string "1" "${CONTENTS_DIR}/Info.plist"
plutil -replace LSMinimumSystemVersion -string "10.13" "${CONTENTS_DIR}/Info.plist"
plutil -remove NSMainNibFile "${CONTENTS_DIR}/Info.plist"
plutil -remove CFBundleIconName "${CONTENTS_DIR}/Info.plist"

for strings_file in "${ROOT_DIR}"/BLEUnlock/*.lproj/Localizable.strings; do
  locale_dir="$(basename "$(dirname "${strings_file}")")"
  mkdir -p "${RESOURCES_DIR}/${locale_dir}"
  cp "${strings_file}" "${RESOURCES_DIR}/${locale_dir}/Localizable.strings"
done

cp "${ROOT_DIR}/BLEUnlock/Images.xcassets/StatusBarDisconnected.imageset/unlock-off.pdf" \
  "${RESOURCES_DIR}/StatusBarDisconnected.pdf"
cp "${ROOT_DIR}/BLEUnlock/Images.xcassets/StatusBarConnected.imageset/app.pdf" \
  "${RESOURCES_DIR}/StatusBarConnected.pdf"

codesign --force --sign - \
  --entitlements "${ROOT_DIR}/BLEUnlock/BLEUnlock.entitlements" \
  "${APP_DIR}"
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "Built ${APP_DIR}"

package_local_app() {
  local staging_dir="${BUILD_DIR}/dmg-root"
  local actual_bundle_id

  rm -rf "${staging_dir}" "${MOUNT_DIR}" "${DMG_PATH}" "${CHECKSUM_PATH}"
  mkdir -p "${staging_dir}" "${MOUNT_DIR}"
  cp -R "${APP_DIR}" "${staging_dir}/BLEUnlockLocal.app"
  ln -s /Applications "${staging_dir}/Applications"

  hdiutil create \
    -volname BLEUnlockLocal \
    -srcfolder "${staging_dir}" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "${DMG_PATH}" >/dev/null
  hdiutil verify "${DMG_PATH}" >/dev/null

  (
    cd "${BUILD_DIR}"
    shasum -a 256 "$(basename "${DMG_PATH}")" >"$(basename "${CHECKSUM_PATH}")"
    shasum -a 256 -c "$(basename "${CHECKSUM_PATH}")"
  )

  hdiutil attach -nobrowse -readonly -mountpoint "${MOUNT_DIR}" "${DMG_PATH}" >/dev/null
  MOUNT_ATTACHED=1
  test -x "${MOUNT_DIR}/BLEUnlockLocal.app/Contents/MacOS/BLEUnlockLocal"
  codesign --verify --deep --strict --verbose=2 "${MOUNT_DIR}/BLEUnlockLocal.app"
  actual_bundle_id="$(defaults read "${MOUNT_DIR}/BLEUnlockLocal.app/Contents/Info" CFBundleIdentifier)"
  if [[ "${actual_bundle_id}" != "${BUNDLE_ID}" ]]; then
    echo "Unexpected packaged bundle identifier: ${actual_bundle_id}" >&2
    exit 1
  fi
  test -L "${MOUNT_DIR}/Applications"
  hdiutil detach "${MOUNT_DIR}" -quiet
  MOUNT_ATTACHED=0

  echo "PASS: packaged and mounted ${DMG_PATH}"
  echo "Checksum: ${CHECKSUM_PATH}"
}

if [[ "${MODE}" == "package" || "${MODE}" == "verify" ]]; then
  package_local_app
fi

if [[ "${MODE}" == "build" || "${MODE}" == "package" ]]; then
  trap - EXIT INT TERM
  exit 0
fi

# Keep the smoke/run instance separate from an installed release and prevent it
# from locking, unlocking, registering at login, or controlling media.
FIXED_USER_HOME="${BUILD_DIR}/test-home"
mkdir -p "${FIXED_USER_HOME}"
export CFFIXED_USER_HOME="${FIXED_USER_HOME}"
defaults write "${BUNDLE_ID}" unlockRSSI -int 1
defaults write "${BUNDLE_ID}" lockRSSI -int -100
defaults write "${BUNDLE_ID}" autoCheckUpdates -bool false
defaults write "${BUNDLE_ID}" launchAtLogin -bool false
defaults write "${BUNDLE_ID}" pauseItunes -bool false
defaults write "${BUNDLE_ID}" runInBackground -bool false
defaults write "${BUNDLE_ID}" wakeOnProximity -bool false
defaults write "${BUNDLE_ID}" legacyBundleIDMigrationComplete -bool true

if [[ "${MODE}" == "run" ]]; then
  echo "Launching isolated local app. Quit it from the BLEUnlock menu when done."
  open -n --env "CFFIXED_USER_HOME=${FIXED_USER_HOME}" "${APP_DIR}"
  trap - EXIT INT TERM
  exit 0
fi

"${EXECUTABLE}" >"${LOG_FILE}" 2>&1 &
local_pid=$!

sleep "${SMOKE_SECONDS}"
if ! kill -0 "${local_pid}" 2>/dev/null; then
  echo "BLEUnlockLocal exited during startup." >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

echo "PASS: BLEUnlockLocal stayed running for ${SMOKE_SECONDS}s (pid=${local_pid})."
cleanup
local_pid=""
trap - EXIT INT TERM
