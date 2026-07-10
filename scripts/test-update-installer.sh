#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_APP="${ROOT_DIR}/build/local-clt/BLEUnlockLocal.app"
TEST_VERSION="9.9.9"
PORT="${BLEUNLOCK_UPDATE_TEST_PORT:-18765}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bleunlock-update-test.XXXXXX")"
WORK_DIR="$(cd "${WORK_DIR}" && pwd -P)"
SERVER_PID=""

cleanup() {
  if [[ -n "${SERVER_PID}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
  pkill -f "${WORK_DIR}/UpdaterHarness.app/Contents/MacOS/BLEUnlockLocal" >/dev/null 2>&1 || true
  if [[ "${BLEUNLOCK_UPDATE_TEST_KEEP:-0}" == "1" ]]; then
    echo "Kept update test workspace: ${WORK_DIR}" >&2
  else
    rm -rf "${WORK_DIR}"
  fi
}
trap cleanup EXIT INT TERM

if [[ ! -d "${LOCAL_APP}" ]]; then
  echo "Missing ${LOCAL_APP}; run scripts/build-local.sh first." >&2
  exit 1
fi

for command in swiftc plutil codesign hdiutil shasum curl python3; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Required command not found: ${command}" >&2
    exit 1
  }
done

HARNESS_APP="${WORK_DIR}/UpdaterHarness.app"
HARNESS_EXECUTABLE="${HARNESS_APP}/Contents/MacOS/UpdateInstallerHarness"
PAYLOAD_DIR="${WORK_DIR}/payload"
SOURCE_APP="${PAYLOAD_DIR}/source/BLEUnlock.app"
DMG_PATH="${PAYLOAD_DIR}/BLEUnlock-test.dmg"

mkdir -p "$(dirname "${HARNESS_EXECUTABLE}")" "${PAYLOAD_DIR}/source"
swiftc -O -framework Cocoa \
  "${ROOT_DIR}/BLEUnlock/checkUpdate.swift" \
  "${ROOT_DIR}/scripts/UpdateInstallerHarness.swift" \
  -o "${HARNESS_EXECUTABLE}"

cp "${ROOT_DIR}/BLEUnlock/Info.plist" "${HARNESS_APP}/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string com.bifrost-proxy.BLEUnlock.UpdaterHarness "${HARNESS_APP}/Contents/Info.plist"
plutil -replace CFBundleExecutable -string UpdateInstallerHarness "${HARNESS_APP}/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string 1.0.0 "${HARNESS_APP}/Contents/Info.plist"
plutil -replace CFBundleVersion -string 1 "${HARNESS_APP}/Contents/Info.plist"
codesign --force --sign - "${HARNESS_APP}"

ditto "${LOCAL_APP}" "${SOURCE_APP}"
plutil -replace CFBundleIdentifier -string com.bifrost-proxy.BLEUnlock "${SOURCE_APP}/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "${TEST_VERSION}" "${SOURCE_APP}/Contents/Info.plist"
plutil -replace CFBundleVersion -string 999 "${SOURCE_APP}/Contents/Info.plist"
MACOS_SIGNING_IDENTITY=- \
MACOS_ENTITLEMENTS_PATH="${ROOT_DIR}/BLEUnlock/BLEUnlock.entitlements" \
  bash "${ROOT_DIR}/scripts/sign-macos-app.sh" "${SOURCE_APP}"

hdiutil create -quiet -fs HFS+ -format UDZO -srcfolder "${PAYLOAD_DIR}/source" "${DMG_PATH}"
(
  cd "${PAYLOAD_DIR}"
  shasum -a 256 "$(basename "${DMG_PATH}")" > "$(basename "${DMG_PATH}").sha256"
)

python3 -m http.server "${PORT}" --bind 127.0.0.1 --directory "${PAYLOAD_DIR}" \
  >"${WORK_DIR}/http.log" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${PORT}/BLEUnlock-test.dmg.sha256" >/dev/null; then
    break
  fi
  sleep 0.2
done

"${HARNESS_EXECUTABLE}" "http://127.0.0.1:${PORT}/BLEUnlock-test.dmg" "${TEST_VERSION}"

for _ in $(seq 1 100); do
  installed_version="$(defaults read "${HARNESS_APP}/Contents/Info" CFBundleShortVersionString 2>/dev/null || true)"
  if [[ "${installed_version}" == "${TEST_VERSION}" ]]; then
    relaunched=0
    for _ in $(seq 1 50); do
      if pgrep -f "${HARNESS_APP}/Contents/MacOS/BLEUnlockLocal" >/dev/null; then
        relaunched=1
        break
      fi
      sleep 0.2
    done
    if [[ "${relaunched}" -ne 1 ]]; then
      echo "Updater installed ${TEST_VERSION}, but the new app did not relaunch." >&2
      exit 1
    fi
    codesign --verify --deep --strict --verbose=2 "${HARNESS_APP}"
    echo "PASS: in-app updater replaced and relaunched version ${TEST_VERSION}."
    exit 0
  fi
  sleep 0.2
done

echo "Updater did not install version ${TEST_VERSION}." >&2
exit 1
