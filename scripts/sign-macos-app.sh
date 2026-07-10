#!/usr/bin/env bash

set -euo pipefail

APP_PATH="${1:-}"
ENTITLEMENTS_PATH="${MACOS_ENTITLEMENTS_PATH:-${2:-}}"

if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "Usage: $0 <path-to-app-bundle> [entitlements-path]" >&2
  exit 2
fi

if [[ -n "${ENTITLEMENTS_PATH}" && ! -f "${ENTITLEMENTS_PATH}" ]]; then
  echo "Entitlements file not found: ${ENTITLEMENTS_PATH}" >&2
  exit 1
fi

IDENTITY="${MACOS_SIGNING_IDENTITY:-${APPLE_SIGNING_IDENTITY:-}}"
if [[ -z "${IDENTITY}" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Developer ID Application/ { print $2; exit }')"
fi
if [[ -z "${IDENTITY}" ]]; then
  IDENTITY="-"
fi

sign_args=(--force --sign "${IDENTITY}")
if [[ "${IDENTITY}" == "-" ]]; then
  sign_args+=(--timestamp=none)
  echo "Signing ${APP_PATH} with an ad-hoc identity."
else
  sign_args+=(--options runtime --timestamp)
  echo "Signing ${APP_PATH} with Developer ID identity: ${IDENTITY}"
fi

is_macho() {
  file -b "$1" | grep -q 'Mach-O'
}

# Sign standalone nested Mach-O files first. Bundle main executables under
# Contents/MacOS are signed with their containing bundle below; asking codesign
# to sign one directly can make it validate the outer bundle before nested apps
# have been signed, making the result depend on find's traversal order.
while IFS= read -r -d '' candidate; do
  if [[ "${candidate}" == */Contents/MacOS/* ]]; then
    continue
  fi
  if is_macho "${candidate}"; then
    /usr/bin/codesign "${sign_args[@]}" "${candidate}"
  fi
done < <(find "${APP_PATH}/Contents" -type f -print0)

# Sign nested bundles from the inside out before signing the outer application.
while IFS= read -r -d '' bundle; do
  /usr/bin/codesign "${sign_args[@]}" "${bundle}"
done < <(find "${APP_PATH}/Contents" -depth -type d \
  \( -name '*.app' -o -name '*.framework' -o -name '*.xpc' -o -name '*.appex' \) \
  -print0)

app_sign_args=("${sign_args[@]}")
if [[ -n "${ENTITLEMENTS_PATH}" ]]; then
  app_sign_args+=(--entitlements "${ENTITLEMENTS_PATH}")
fi
/usr/bin/codesign "${app_sign_args[@]}" "${APP_PATH}"
/usr/bin/codesign --verify --deep --strict --verbose=4 "${APP_PATH}"

echo "PASS: signed and verified ${APP_PATH}"
