#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Burning Windows automatic AUR uploader
# LOCAL SOURCE version: 2026-06-13-6
#
# This script does NOT use GitHub as the package source.
# It creates a source tarball from the local project directory
# and commits that tarball into the AUR package repository.
#
# Users can then install with:
#   yay -S burning-windows
# ============================================================

PKGNAME="burning-windows"
PKGVER="0.1.1"
PKGREL="1"
PKGDESC="Burning Windows effect for KDE Plasma/KWin"

# Kept for reference only. This LOCAL SOURCE script does not download from GitHub.
GITHUB_REPO="yousefvand/Burning-Windows"
GITHUB_TAG="local-source"
SOURCE_URL="local-source-tarball-committed-to-AUR"

AUR_REPO="ssh://aur@aur.archlinux.org/${PKGNAME}.git"
WORKDIR="/tmp/aur-${PKGNAME}"
LOCAL_PROJECT_DIR="$(pwd)"
SOURCE_DIR_NAME="${PKGNAME}-${PKGVER}"
SOURCE_FILE="${PKGNAME}-${PKGVER}.tar.gz"
SRC_DIR="${SOURCE_DIR_NAME}"

msg() { printf '\n==> %s\n' "$*"; }
err() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || err "git is required"
command -v tar >/dev/null || err "tar is required"
command -v makepkg >/dev/null || err "makepkg is required"
command -v sha256sum >/dev/null || err "sha256sum is required"

if [[ $# -ne 0 ]]; then
  err "This script accepts no arguments. Edit variables at the top of aur.sh instead."
fi

msg "aur.sh LOCAL SOURCE version: 2026-06-13-6"
msg "Using local project directory: ${LOCAL_PROJECT_DIR}"

# Safety: must be run from the project root.
[[ -f "${LOCAL_PROJECT_DIR}/CMakeLists.txt" ]] || err "Run this from the Burning-Windows project root. Missing CMakeLists.txt"
[[ -f "${LOCAL_PROJECT_DIR}/install.sh" ]] || err "Run this from the Burning-Windows project root. Missing install.sh"
[[ -d "${LOCAL_PROJECT_DIR}/src" ]] || err "Run this from the Burning-Windows project root. Missing src/"
[[ -f "${LOCAL_PROJECT_DIR}/src/CMakeLists.txt" ]] || err "Missing src/CMakeLists.txt"
[[ -f "${LOCAL_PROJECT_DIR}/src/kpackage/burning_windows/metadata.json" ]] || err "Missing src/kpackage/burning_windows/metadata.json"
[[ -f "${LOCAL_PROJECT_DIR}/src/kpackage/burning_windows/contents/ui/main.qml" ]] || err "Missing src/kpackage/burning_windows/contents/ui/main.qml"

TMPDIR_LOCAL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

msg "Creating local source tarball from current project files"
mkdir -p "${TMPDIR_LOCAL}/${SOURCE_DIR_NAME}"

# Copy local project into a clean source directory.
# Exclude build outputs, git metadata, old AUR workdirs, packages, caches, and editor junk.
tar \
  --exclude='./.git' \
  --exclude='./.github' \
  --exclude='./build' \
  --exclude='./cmake-build-*' \
  --exclude='./aur-burning-windows' \
  --exclude='./aur-*' \
  --exclude='./src' \
  --exclude='./pkg' \
  --exclude='./*.pkg.tar.*' \
  --exclude='./*.tar.gz' \
  --exclude='./*.tar.xz' \
  --exclude='./*.tar.zst' \
  --exclude='./.SRCINFO' \
  --exclude='./PKGBUILD' \
  --exclude='./*.log' \
  --exclude='./.cache' \
  --exclude='./.idea' \
  --exclude='./.vscode' \
  --exclude='./__pycache__' \
  --exclude='./aur.sh' \
  -C "${LOCAL_PROJECT_DIR}" \
  -cf - . | tar -C "${TMPDIR_LOCAL}/${SOURCE_DIR_NAME}" -xf -

# The previous tar command intentionally excluded ./src by mistake in older attempts.
# Copy src explicitly so we can fail loudly if it is incomplete.
mkdir -p "${TMPDIR_LOCAL}/${SOURCE_DIR_NAME}/src"
tar \
  --exclude='./build' \
  --exclude='./cmake-build-*' \
  --exclude='./*.o' \
  --exclude='./*.so' \
  --exclude='./*.a' \
  --exclude='./.cache' \
  -C "${LOCAL_PROJECT_DIR}/src" \
  -cf - . | tar -C "${TMPDIR_LOCAL}/${SOURCE_DIR_NAME}/src" -xf -

[[ -f "${TMPDIR_LOCAL}/${SOURCE_DIR_NAME}/CMakeLists.txt" ]] || err "Local tarball staging missing CMakeLists.txt"
[[ -f "${TMPDIR_LOCAL}/${SOURCE_DIR_NAME}/install.sh" ]] || err "Local tarball staging missing install.sh"
[[ -f "${TMPDIR_LOCAL}/${SOURCE_DIR_NAME}/src/CMakeLists.txt" ]] || err "Local tarball staging missing src/CMakeLists.txt"
[[ -f "${TMPDIR_LOCAL}/${SOURCE_DIR_NAME}/src/kpackage/burning_windows/metadata.json" ]] || err "Local tarball staging missing metadata.json"
[[ -f "${TMPDIR_LOCAL}/${SOURCE_DIR_NAME}/src/kpackage/burning_windows/contents/ui/main.qml" ]] || err "Local tarball staging missing main.qml"

# Normalize owner/group for reproducible archive metadata.
tar --sort=name --owner=0 --group=0 --numeric-owner \
  -C "${TMPDIR_LOCAL}" \
  -czf "${TMPDIR_LOCAL}/${SOURCE_FILE}" \
  "${SOURCE_DIR_NAME}"

SHA256SUM="$(sha256sum "${TMPDIR_LOCAL}/${SOURCE_FILE}" | awk '{print $1}')"
SOURCE_SIZE="$(du -h "${TMPDIR_LOCAL}/${SOURCE_FILE}" | awk '{print $1}')"
echo "Local source tarball: ${SOURCE_FILE}"
echo "Tarball size: ${SOURCE_SIZE}"
echo "SHA256: ${SHA256SUM}"

msg "Preparing AUR working directory: ${WORKDIR}"
rm -rf "${WORKDIR}"

if git clone "${AUR_REPO}" "${WORKDIR}"; then
  msg "Cloned existing AUR repository"
else
  msg "Could not clone existing repo; creating fresh local AUR repository"
  mkdir -p "${WORKDIR}"
  git -C "${WORKDIR}" init
  git -C "${WORKDIR}" remote add origin "${AUR_REPO}"
fi

cd "${WORKDIR}"

if git rev-parse --verify master >/dev/null 2>&1; then
  git checkout master
fi

msg "Cleaning AUR working tree"
git reset --hard HEAD >/dev/null 2>&1 || true
git clean -fdx >/dev/null 2>&1 || true
rm -rf src pkg "${SRC_DIR}" "${PKGNAME}-${PKGVER}" *.pkg.tar.* *.pkg.tar.*.sig *.log
rm -f ./*.tar.gz ./*.tar.zst ./*.tar.xz ./*.zip

cp "${TMPDIR_LOCAL}/${SOURCE_FILE}" "${SOURCE_FILE}"
LOCAL_SHA="$(sha256sum "${SOURCE_FILE}" | awk '{print $1}')"
[[ "${LOCAL_SHA}" == "${SHA256SUM}" ]] || err "Copied source tarball checksum mismatch"

msg "Writing PKGBUILD for local AUR-committed source tarball"
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
source=("${SOURCE_FILE}")
sha256sums=('${SHA256SUM}')

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

msg "Verifying local AUR source tarball through makepkg"
SRCDEST="$PWD" makepkg --verifysource --noconfirm

msg "Building package locally from the AUR-committed tarball"
SRCDEST="$PWD" makepkg -f --clean --syncdeps --noconfirm

msg "Checking package installed-file list"
PKGFILE="$(ls -1 ${PKGNAME}-${PKGVER}-${PKGREL}-*.pkg.tar.* | head -n 1)"
bsdtar -tf "$PKGFILE" | grep -E 'remisa_burn|burning_windows|main.qml|metadata.json' || err "Built package does not contain expected KWin files"

msg "Removing build artifacts before AUR commit, keeping source tarball"
rm -rf src pkg "${SRC_DIR}" "${PKGNAME}-${PKGVER}" *.pkg.tar.* *.pkg.tar.*.sig *.log

git add PKGBUILD .SRCINFO burning-windows.install "${SOURCE_FILE}"

if git diff --cached --quiet; then
  msg "No AUR changes to commit"
else
  git commit -m "Package ${PKGNAME} ${PKGVER}-${PKGREL} from local source"
fi

msg "Pushing to AUR"
git push origin master

msg "Done. Users can install with: yay -S ${PKGNAME}"
echo "This AUR package now builds from the local source tarball committed into the AUR repo."
echo "Tell users to reboot after installation."
