#!/usr/bin/env bash
set -euo pipefail

PKGNAME="burning-windows"
PKGVER="0.1.3"
GITHUB_REPO="yousefvand/Burning-Windows"
GITHUB_TAG="0.1.3"
SOURCE_URL="https://github.com/${GITHUB_REPO}/archive/refs/tags/${GITHUB_TAG}.tar.gz"
SOURCE_FILE="${PKGNAME}-${PKGVER}.tar.gz"
TMPDIR_BASE="/tmp/${PKGNAME}-sha256-check"

msg() { printf '\n==> %s\n' "$*"; }
err() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || err "curl is required"
command -v sha256sum >/dev/null || err "sha256sum is required"
command -v tar >/dev/null || err "tar is required"

rm -rf "${TMPDIR_BASE}"
mkdir -p "${TMPDIR_BASE}"

msg "Downloading release tarball to /tmp"
echo "URL: ${SOURCE_URL}"
curl -L --fail --retry 3 --retry-delay 2 -o "${TMPDIR_BASE}/${SOURCE_FILE}" "${SOURCE_URL}"

SHA256SUM="$(sha256sum "${TMPDIR_BASE}/${SOURCE_FILE}" | awk '{print $1}')"
SIZE="$(du -h "${TMPDIR_BASE}/${SOURCE_FILE}" | awk '{print $1}')"
tar -tzf "${TMPDIR_BASE}/${SOURCE_FILE}" > "${TMPDIR_BASE}/tar-list.txt"
ROOT_DIR="$(sed -n '1s#/.*##p' "${TMPDIR_BASE}/tar-list.txt")"

msg "Downloaded tarball information"
echo "File: ${TMPDIR_BASE}/${SOURCE_FILE}"
echo "Size: ${SIZE}"
echo "Root directory inside tarball: ${ROOT_DIR}"
echo "PKGVER: ${PKGVER}"
echo "GITHUB_TAG: ${GITHUB_TAG}"
echo "SHA256: ${SHA256SUM}"

msg "Paste these values into aur.sh"
cat <<VALUES_EOF
PKGVER="${PKGVER}"
GITHUB_TAG="${GITHUB_TAG}"
EXPECTED_SHA256="${SHA256SUM}"
VALUES_EOF

msg "Expected PKGBUILD source line"
echo "source=(\"\${pkgname}-\${pkgver}.tar.gz::${SOURCE_URL}\")"
