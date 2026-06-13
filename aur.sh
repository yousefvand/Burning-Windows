#!/usr/bin/env bash
set -euo pipefail

PKGNAME="burning-windows"
PKGVER="0.1.1"
PKGREL="1"
PKGDESC="Burning Windows effect for KDE Plasma/KWin"

GITHUB_REPO="yousefvand/Burning-Windows"
GITHUB_TAG="0.1.1"
SOURCE_URL="https://github.com/${GITHUB_REPO}/archive/refs/tags/${GITHUB_TAG}.tar.gz"

EXPECTED_SHA256="7b2e5a487adb4cbd92212f669db42f31c94cfc214a8b03a06caccc9d8ec5ee19"

AUR_REPO="ssh://aur@aur.archlinux.org/${PKGNAME}.git"
WORKDIR="/tmp/aur-${PKGNAME}"
SOURCE_FILE="${PKGNAME}-${PKGVER}.tar.gz"
SRC_DIR="Burning-Windows-${GITHUB_TAG}"

msg() { printf '\n==> %s\n' "$*"; }
err() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || err "git is required"
command -v curl >/dev/null || err "curl is required"
command -v makepkg >/dev/null || err "makepkg is required"
command -v sha256sum >/dev/null || err "sha256sum is required"
command -v tar >/dev/null || err "tar is required"

if [[ $# -ne 0 ]]; then
  err "This script accepts no arguments. Edit variables at the top of aur.sh instead."
fi

msg "aur.sh hardcoded SHA256 version: 2026-06-13-12"

if [[ ! "${EXPECTED_SHA256}" =~ ^[0-9a-fA-F]{64}$ ]]; then
  err "Set EXPECTED_SHA256 to the trusted 64-character SHA256 before publishing."
fi

TMPDIR_CHECK="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_CHECK}"' EXIT

msg "Verifying GitHub tag tarball against hardcoded SHA256"
echo "URL: ${SOURCE_URL}"
curl -L --fail --retry 3 --retry-delay 2 -o "${TMPDIR_CHECK}/${SOURCE_FILE}" "${SOURCE_URL}"
ACTUAL_SHA256="$(sha256sum "${TMPDIR_CHECK}/${SOURCE_FILE}" | awk '{print $1}')"
tar -tzf "${TMPDIR_CHECK}/${SOURCE_FILE}" > "${TMPDIR_CHECK}/tar-list.txt"
ROOT_DIR="$(sed -n '1s#/.*##p' "${TMPDIR_CHECK}/tar-list.txt")"

echo "Expected SHA256: ${EXPECTED_SHA256}"
echo "Actual SHA256:   ${ACTUAL_SHA256}"
echo "Tarball root:    ${ROOT_DIR}"

[[ "${ACTUAL_SHA256}" == "${EXPECTED_SHA256}" ]] || err "Downloaded tarball does not match hardcoded SHA256. Refusing to publish."
[[ "${ROOT_DIR}" == "${SRC_DIR}" ]] || err "Unexpected tarball root '${ROOT_DIR}'. Expected '${SRC_DIR}'. Check GITHUB_TAG/SRC_DIR."

msg "Preparing AUR working directory: ${WORKDIR}"
rm -rf "${WORKDIR}"

if git clone "${AUR_REPO}" "${WORKDIR}"; then
  msg "Cloned existing AUR repository"
else
  msg "Could not clone existing AUR repo; creating fresh local AUR repository"
  mkdir -p "${WORKDIR}"
  git -C "${WORKDIR}" init
  git -C "${WORKDIR}" remote add origin "${AUR_REPO}"
fi

cd "${WORKDIR}"

if git rev-parse --verify master >/dev/null 2>&1; then
  git checkout master
fi

msg "Cleaning AUR working tree and removing wrongly committed source archives"
git reset --hard HEAD >/dev/null 2>&1 || true
git clean -fdx >/dev/null 2>&1 || true
rm -rf src pkg build "${SRC_DIR}" "${PKGNAME}-${PKGVER}" *.pkg.tar.* *.pkg.tar.*.sig *.log
rm -f ./*.tar.gz ./*.tar.xz ./*.tar.zst ./*.zip

msg "Writing PKGBUILD"
cat > PKGBUILD <<PKGBUILD_EOF
# Maintainer: Masoud Yousefvand <yousefvand@gmail.com>
pkgname=${PKGNAME}
pkgver=${PKGVER}
pkgrel=${PKGREL}
pkgdesc='${PKGDESC}'
arch=('x86_64')
url='https://github.com/${GITHUB_REPO}'
license=('GPL')
depends=(
  'kwin'
  'kcoreaddons'
  'kconfig'
  'kconfigwidgets'
  'ki18n'
  'kcmutils'
  'qt6-base'
  'qt6-declarative'
)
makedepends=(
  'cmake'
  'extra-cmake-modules'
  'ninja'
  'gcc'
)
install='burning-windows.install'
source=("${PKGNAME}-${PKGVER}.tar.gz::https://github.com/${GITHUB_REPO}/archive/refs/tags/${GITHUB_TAG}.tar.gz")
sha256sums=('${EXPECTED_SHA256}')

build() {
  cmake -S "\$srcdir/${SRC_DIR}" -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DKDE_INSTALL_LIBDIR=lib \
    -DKDE_INSTALL_LIBEXECDIR=lib \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
  cmake --build build
}

package() {
  DESTDIR="\$pkgdir" cmake --install build
}
PKGBUILD_EOF

msg "Writing pacman install script"
cat > burning-windows.install <<'INSTALL_EOF'
post_install() {
  echo ""
  echo "Burning Windows has been installed."
  echo ""
  echo "IMPORTANT: KDE's built-in 'Fall Apart' effect conflicts with Burning Windows."
  echo "This package tries to enable Burning Windows and disable conflicting effects for the installing user."
  echo "If it does not apply automatically, set these in ~/.config/kwinrc under [Plugins]:"
  echo "  remisa_burnEnabled=true"
  echo "  burning_windowsEnabled=true"
  echo "  fallapartEnabled=false"
  echo "  glideEnabled=false"
  echo ""

  target_user="${SUDO_USER:-}"
  if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
    target_user="$(logname 2>/dev/null || true)"
  fi

  if [ -n "$target_user" ] && command -v runuser >/dev/null 2>&1; then
    runuser -u "$target_user" -- kwriteconfig6 --file kwinrc --group Plugins --key remisa_burnEnabled true 2>/dev/null || true
    runuser -u "$target_user" -- kwriteconfig6 --file kwinrc --group Plugins --key burning_windowsEnabled true 2>/dev/null || true
    runuser -u "$target_user" -- kwriteconfig6 --file kwinrc --group Plugins --key fallapartEnabled false 2>/dev/null || true
    runuser -u "$target_user" -- kwriteconfig6 --file kwinrc --group Plugins --key glideEnabled false 2>/dev/null || true
  fi

  echo "Please REBOOT your system now. Do not only logout/login."
  echo ""
}

post_upgrade() {
  post_install
}

post_remove() {
  echo "Burning Windows has been removed. Reboot KDE Plasma to fully unload the effect."
}
INSTALL_EOF

msg "Generating .SRCINFO"
makepkg --printsrcinfo > .SRCINFO

msg "Verifying source through makepkg"
SRCDEST="${TMPDIR_CHECK}" makepkg --verifysource --noconfirm

msg "Building package locally before publishing"
SRCDEST="${TMPDIR_CHECK}" makepkg -f --clean --syncdeps --noconfirm

msg "Checking package installed-file list"
PKGFILE="$(find . -maxdepth 1 -type f -name "${PKGNAME}-${PKGVER}-${PKGREL}-*.pkg.tar.*" | sort | sed -n '1p')"
bsdtar -tf "${PKGFILE}" | grep -E 'remisa_burn|burning_windows|main.qml|metadata.json' || err "Built package does not contain expected KWin files"

msg "Removing build artifacts before AUR commit"
rm -rf src pkg build "${SRC_DIR}" "${PKGNAME}-${PKGVER}" *.pkg.tar.* *.pkg.tar.*.sig *.log
rm -f ./*.tar.gz ./*.tar.xz ./*.tar.zst ./*.zip

git add PKGBUILD .SRCINFO burning-windows.install

if git diff --cached --quiet; then
  msg "No AUR changes to commit"
else
  git commit -m "Update ${PKGNAME} to ${PKGVER}-${PKGREL}"
fi

msg "Pushing to AUR"
git push origin master

msg "Done. Users can install with: yay -S ${PKGNAME}"
