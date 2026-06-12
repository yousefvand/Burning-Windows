#!/usr/bin/env bash
set -euo pipefail

# Publish Burning Windows to the Arch User Repository.
# Run this from the project root:
#   ./aur.sh
#
# The script creates an AUR repo for package name "burning-windows",
# commits PKGBUILD/.SRCINFO plus a small source tarball, and pushes to AUR.

PKGNAME="burning-windows"
PKGVER="0.1.0"
PKGREL="1"
PKGDESC="Burning window close animation for KDE Plasma 6 KWin Wayland"
AUTHOR="Remisa Phillips"
AUR_REMOTE="ssh://aur@aur.archlinux.org/${PKGNAME}.git"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${ROOT_DIR}/.aur-work"
AUR_DIR="${WORK_DIR}/${PKGNAME}"
SRC_TARBALL="${PKGNAME}-${PKGVER}.tar.gz"
SKIP_BUILD=0
AUTO_PUSH=0

for arg in "${@:-}"; do
    case "$arg" in
        --no-build) SKIP_BUILD=1 ;;
        --push) AUTO_PUSH=1 ;;
        -h|--help)
            cat <<HELP
Usage: ./aur.sh [--no-build] [--push]

Creates/updates the AUR package: ${PKGNAME}

Options:
  --no-build   Do not run makepkg test build before pushing.
  --push       Push without asking for confirmation.
HELP
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing command: $1" >&2
        echo "Install it first, then run ./aur.sh again." >&2
        exit 1
    fi
}

need_cmd git
need_cmd tar
need_cmd rsync
need_cmd sha256sum
need_cmd makepkg
need_cmd cmake

cd "$ROOT_DIR"

if [[ ! -f "CMakeLists.txt" || ! -d "src" ]]; then
    echo "Run this script from the Burning Windows project root." >&2
    exit 1
fi

if [[ ! -f "LICENSE" ]]; then
    echo "LICENSE file not found. AUR package expects LICENSE in project root." >&2
    exit 1
fi

mkdir -p "$WORK_DIR"

if [[ -d "$AUR_DIR/.git" ]]; then
    echo "[1/8] Updating existing AUR working tree..."
    git -C "$AUR_DIR" fetch origin
    git -C "$AUR_DIR" checkout master || git -C "$AUR_DIR" checkout main
    git -C "$AUR_DIR" pull --rebase
else
    echo "[1/8] Cloning AUR repository..."
    rm -rf "$AUR_DIR"
    git clone "$AUR_REMOTE" "$AUR_DIR"
fi

# Clean old generated files, but keep the .git directory.
echo "[2/8] Cleaning AUR working tree..."
find "$AUR_DIR" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT
SRC_ROOT="${STAGE_DIR}/${PKGNAME}-${PKGVER}"
mkdir -p "$SRC_ROOT"

echo "[3/8] Creating source tarball..."
rsync -a "$ROOT_DIR/" "$SRC_ROOT/" \
    --exclude='.git' \
    --exclude='.aur-work' \
    --exclude='build' \
    --exclude='*.tar.gz' \
    --exclude='rescue-remisa.sh' \
    --exclude='PKGBUILD' \
    --exclude='.SRCINFO'

tar -C "$STAGE_DIR" -czf "${AUR_DIR}/${SRC_TARBALL}" "${PKGNAME}-${PKGVER}"
SHA256="$(sha256sum "${AUR_DIR}/${SRC_TARBALL}" | awk '{print $1}')"

cat > "${AUR_DIR}/PKGBUILD" <<PKGBUILD
# Maintainer: ${AUTHOR}

pkgname=${PKGNAME}
pkgver=${PKGVER}
pkgrel=${PKGREL}
pkgdesc='${PKGDESC}'
arch=('x86_64')
url='https://aur.archlinux.org/packages/${PKGNAME}'
license=('MIT')
depends=('kwin' 'qt6-base' 'qt6-declarative' 'kcoreaddons' 'ki18n')
makedepends=('cmake' 'extra-cmake-modules' 'qt6-tools')
provides=('kwin6-effect-remisa-burn')
conflicts=('kwin6-effect-remisa-burn')
install='${PKGNAME}.install'
source=('${SRC_TARBALL}')
sha256sums=('${SHA256}')

build() {
    cmake -S "\$srcdir/${PKGNAME}-${PKGVER}" -B build \
        -DCMAKE_BUILD_TYPE=None \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -Wno-dev
    cmake --build build
}

package() {
    DESTDIR="\$pkgdir" cmake --install build
    install -Dm644 "\$srcdir/${PKGNAME}-${PKGVER}/LICENSE" \
        "\$pkgdir/usr/share/licenses/\$pkgname/LICENSE"
}
PKGBUILD

cat > "${AUR_DIR}/${PKGNAME}.install" <<'INSTALL'
post_install() {
    cat <<'MSG'

Burning Windows has been installed.

For first use, log out and log back in, or reboot once.
Then enable/disable it from:

  System Settings -> Desktop Effects -> Burning Windows

No restart is needed for normal enable/disable after the first login/reboot.

MSG
}

post_upgrade() {
    post_install
}

post_remove() {
    cat <<'MSG'

Burning Windows has been removed.
Log out/in or reboot if KWin still has the old plugin loaded in this session.

MSG
}
INSTALL

cd "$AUR_DIR"

echo "[4/8] Generating .SRCINFO..."
makepkg --printsrcinfo > .SRCINFO

if [[ "$SKIP_BUILD" -eq 0 ]]; then
    echo "[5/8] Test building package with makepkg..."
    makepkg --cleanbuild --syncdeps --needed
else
    echo "[5/8] Skipping makepkg test build."
fi

echo "[6/8] AUR files ready:"
ls -l PKGBUILD .SRCINFO "${PKGNAME}.install" "$SRC_TARBALL"

echo "[7/8] Git status:"
git status --short

git add PKGBUILD .SRCINFO "${PKGNAME}.install" "$SRC_TARBALL"

if git diff --cached --quiet; then
    echo "No changes to commit."
else
    git commit -m "Initial release ${PKGVER}-${PKGREL}"
fi

if [[ "$AUTO_PUSH" -ne 1 ]]; then
    echo
    read -r -p "Push ${PKGNAME} ${PKGVER}-${PKGREL} to AUR now? [y/N] " answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *)
            echo "Not pushed. AUR working tree is here: $AUR_DIR"
            exit 0
            ;;
    esac
fi

echo "[8/8] Pushing to AUR..."
git push origin HEAD:master

cat <<DONE

Done.
AUR package published/updated:
  ${PKGNAME}

Users can install it with:
  yay -S ${PKGNAME}

DONE
