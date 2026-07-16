#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 -m json.tool "$ROOT_DIR/package/metadata.json" >/dev/null
bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/uninstall.sh"
bash -n "$ROOT_DIR/aur.sh"

if command -v node >/dev/null 2>&1; then
    node --check "$ROOT_DIR/package/contents/code/main.js"
fi

for shader in burn.frag burn_core.frag; do
    test -s "$ROOT_DIR/package/contents/shaders/$shader"
done

grep -q '"Version": "0.1.1"' "$ROOT_DIR/package/metadata.json"
grep -q '"Id": "kwin4_effect_burning_windows"' "$ROOT_DIR/package/metadata.json"
grep -q '"X-Plasma-MainScript": "code/main.js"' "$ROOT_DIR/package/metadata.json"
grep -q 'project(burning-windows VERSION 0.1.1' "$ROOT_DIR/CMakeLists.txt"
grep -q 'COMMIT_MESSAGE=.*git log -1 --pretty=%s' "$ROOT_DIR/aur.sh"
grep -q 'git ls-remote' "$ROOT_DIR/aur.sh"
! grep -q 'git push.*github' "$ROOT_DIR/aur.sh"
! grep -q -- '--version\|--commit\|--push\|--pkgrel' "$ROOT_DIR/aur.sh"
grep -q 'pkgver=@PKGVER@' "$ROOT_DIR/packaging/PKGBUILD.template"
grep -q "_commit='@GITHUB_COMMIT@'" "$ROOT_DIR/packaging/PKGBUILD.template"
grep -q "_archive_root='@ARCHIVE_ROOT@'" "$ROOT_DIR/packaging/PKGBUILD.template"
! grep -q '^package()[[:space:]]*{' "$ROOT_DIR/aur.sh"

RENDERED_PKGBUILD="$(mktemp)"
sed \
    -e 's|@PKGVER@|0.1.1|g' \
    -e 's|@PKGREL@|1|g' \
    -e 's|@GITHUB_REPO@|yousefvand/Burning-Windows|g' \
    -e 's|@GITHUB_COMMIT@|0123456789abcdef0123456789abcdef01234567|g' \
    -e 's|@ARCHIVE_ROOT@|Burning-Windows-0123456789abcdef0123456789abcdef01234567|g' \
    -e 's|@SHA256@|0000000000000000000000000000000000000000000000000000000000000000|g' \
    "$ROOT_DIR/packaging/PKGBUILD.template" > "$RENDERED_PKGBUILD"
bash -n "$RENDERED_PKGBUILD"
rm -f "$RENDERED_PKGBUILD"

BUILD_DIR="$(mktemp -d)"
DEST_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR" "$DEST_DIR"' EXIT
cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
DESTDIR="$DEST_DIR" cmake --install "$BUILD_DIR" >/dev/null

test -f "$DEST_DIR/usr/local/share/kwin/effects/kwin4_effect_burning_windows/metadata.json"
test -f "$DEST_DIR/usr/local/share/kwin/effects/kwin4_effect_burning_windows/contents/code/main.js"
test -f "$DEST_DIR/usr/local/share/kwin/effects/kwin4_effect_burning_windows/contents/shaders/burn.frag"
test -f "$DEST_DIR/usr/local/share/kwin/effects/kwin4_effect_burning_windows/contents/shaders/burn_core.frag"

echo "All static and packaging validation checks passed."
