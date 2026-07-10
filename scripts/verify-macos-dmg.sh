#!/usr/bin/env bash

set -euo pipefail

DMG_PATH="${1:-}"
EXPECTED_BUNDLE_ID="${EXPECTED_BUNDLE_ID:-com.bifrost-proxy.BLEUnlock}"

if [[ -z "${DMG_PATH}" || ! -f "${DMG_PATH}" ]]; then
  echo "Usage: $0 <path-to-dmg>" >&2
  exit 2
fi

MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bleunlock-dmg-verify.XXXXXX")"
MOUNTED=0

cleanup() {
  if [[ "${MOUNTED}" -eq 1 ]]; then
    hdiutil detach "${MOUNT_DIR}" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "${MOUNT_DIR}"
}
trap cleanup EXIT INT TERM

hdiutil verify "${DMG_PATH}" >/dev/null
hdiutil attach -nobrowse -readonly -mountpoint "${MOUNT_DIR}" "${DMG_PATH}" >/dev/null
MOUNTED=1

APP_PATH="$(find "${MOUNT_DIR}" -maxdepth 2 -type d -name '*.app' | head -n 1)"
if [[ -z "${APP_PATH}" ]]; then
  echo "No app bundle found in ${DMG_PATH}." >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict --verbose=4 "${APP_PATH}"

ACTUAL_BUNDLE_ID="$(defaults read "${APP_PATH}/Contents/Info" CFBundleIdentifier)"
if [[ "${ACTUAL_BUNDLE_ID}" != "${EXPECTED_BUNDLE_ID}" ]]; then
  echo "Expected bundle ID ${EXPECTED_BUNDLE_ID}, got ${ACTUAL_BUNDLE_ID}." >&2
  exit 1
fi

while IFS= read -r -d '' candidate; do
  if file -b "${candidate}" | grep -q 'Mach-O'; then
    /usr/bin/codesign --verify --strict --verbose=2 "${candidate}"
  fi
done < <(find "${APP_PATH}/Contents" -type f -print0)

echo "PASS: verified signed app inside ${DMG_PATH}"
