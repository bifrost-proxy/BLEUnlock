#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="bifrost-proxy/BLEUnlock"
INSTALL_DIR="${BLEUNLOCK_INSTALL_DIR:-/Applications}"
RELEASE_TAG="${BLEUNLOCK_VERSION:-}"
LAUNCH_APP=1

usage() {
  cat <<'EOF'
Install the latest BLEUnlock GitHub Release into /Applications.

Usage:
  install.sh [--version vX.Y.Z] [--install-dir DIR] [--no-launch]

Environment variables:
  BLEUNLOCK_VERSION       Release tag to install, for example v1.14.3
  BLEUNLOCK_INSTALL_DIR   Destination directory (default: /Applications)
EOF
}

die() {
  printf 'BLEUnlock installer: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || die "--version requires a value"
      RELEASE_TAG="$2"
      shift 2
      ;;
    --install-dir)
      [[ $# -ge 2 ]] || die "--install-dir requires a value"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --no-launch)
      LAUNCH_APP=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "macOS is required"

for command in curl hdiutil shasum ditto; do
  command -v "${command}" >/dev/null 2>&1 || die "required command not found: ${command}"
done

if [[ -z "${RELEASE_TAG}" ]]; then
  latest_url="$(curl --fail --silent --show-error --location \
    --output /dev/null \
    --write-out '%{url_effective}' \
    "https://github.com/${REPOSITORY}/releases/latest")"
  RELEASE_TAG="${latest_url##*/}"
fi

[[ "${RELEASE_TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
  die "release tag must match vX.Y.Z: ${RELEASE_TAG}"

asset_name="BLEUnlock-${RELEASE_TAG}.dmg"
download_base="https://github.com/${REPOSITORY}/releases/download/${RELEASE_TAG}"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bleunlock-install.XXXXXX")"
mount_point=""

cleanup() {
  if [[ -n "${mount_point}" ]]; then
    hdiutil detach "${mount_point}" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

printf 'Downloading BLEUnlock %s...\n' "${RELEASE_TAG}"
curl --fail --silent --show-error --location \
  --output "${tmp_dir}/${asset_name}" \
  "${download_base}/${asset_name}"
curl --fail --silent --show-error --location \
  --output "${tmp_dir}/${asset_name}.sha256" \
  "${download_base}/${asset_name}.sha256"

(
  cd "${tmp_dir}"
  shasum -a 256 -c "${asset_name}.sha256"
)

attach_output="$(hdiutil attach -nobrowse -readonly "${tmp_dir}/${asset_name}")"
mount_point="$(printf '%s\n' "${attach_output}" | awk -F '\t' '/\/Volumes\// { print $NF; exit }')"
[[ -n "${mount_point}" ]] || die "could not locate the mounted DMG"

source_app="${mount_point}/BLEUnlock.app"
destination_app="${INSTALL_DIR%/}/BLEUnlock.app"
[[ -d "${source_app}" ]] || die "BLEUnlock.app is missing from the DMG"

osascript -e 'tell application id "com.bifrost-proxy.BLEUnlock" to quit' >/dev/null 2>&1 || true
osascript -e 'tell application id "com.github.Skyearn.BLEUnlock" to quit' >/dev/null 2>&1 || true

copy_app() {
  rm -rf "${destination_app}"
  ditto "${source_app}" "${destination_app}"
}

if [[ -d "${INSTALL_DIR}" && -w "${INSTALL_DIR}" ]]; then
  copy_app
else
  command -v sudo >/dev/null 2>&1 || die "${INSTALL_DIR} is not writable and sudo is unavailable"
  printf 'Administrator permission is required to install into %s.\n' "${INSTALL_DIR}"
  sudo mkdir -p "${INSTALL_DIR}"
  sudo rm -rf "${destination_app}"
  sudo ditto "${source_app}" "${destination_app}"
fi

printf 'Installed BLEUnlock %s to %s\n' "${RELEASE_TAG}" "${destination_app}"

if [[ ${LAUNCH_APP} -eq 1 ]]; then
  open "${destination_app}"
fi
