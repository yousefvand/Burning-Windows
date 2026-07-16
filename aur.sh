#!/usr/bin/env bash
set -euo pipefail

PKGNAME="burning-windows"
PKGREL="1"
GITHUB_REPO="yousefvand/Burning-Windows"
AUR_REPO="ssh://aur@aur.archlinux.org/${PKGNAME}.git"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

for cmd in git curl sha256sum tar sed awk grep makepkg bsdtar; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: $cmd is required." >&2
        exit 1
    }
done

[[ -d .git ]] || {
    echo "ERROR: aur.sh must be run from the Burning-Windows Git repository." >&2
    exit 1
}

COMMIT_MESSAGE="$(git log -1 --pretty=%s)"
if [[ ! "$COMMIT_MESSAGE" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    echo "ERROR: the latest commit message must be a version such as v0.1.1." >&2
    echo "Current message: $COMMIT_MESSAGE" >&2
    exit 1
fi

PKGVER="${BASH_REMATCH[1]}"
GITHUB_COMMIT="$(git rev-parse HEAD)"
CURRENT_BRANCH="$(git branch --show-current)"

[[ -n "$CURRENT_BRANCH" ]] || {
    echo "ERROR: detached HEAD is not supported." >&2
    exit 1
}

# aur.sh never pushes the project to GitHub. It only verifies that the current
# release commit is already available there before publishing the AUR package.
REMOTE_SHA="$(
    git ls-remote "https://github.com/${GITHUB_REPO}.git" "refs/heads/${CURRENT_BRANCH}" \
        | awk 'NR == 1 {print $1}'
)"

if [[ "$REMOTE_SHA" != "$GITHUB_COMMIT" ]]; then
    echo "ERROR: the current commit is not the tip of GitHub branch ${CURRENT_BRANCH}." >&2
    echo "Push the project to GitHub first, then run ./aur.sh again." >&2
    echo "Local:  $GITHUB_COMMIT" >&2
    echo "Remote: ${REMOTE_SHA:-not found}" >&2
    exit 1
fi

METADATA_VERSION="$(sed -n 's/.*"Version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' package/metadata.json | head -n 1)"
if [[ "$METADATA_VERSION" != "$PKGVER" ]]; then
    echo "ERROR: package/metadata.json is version ${METADATA_VERSION:-unknown}, but the commit is v${PKGVER}." >&2
    exit 1
fi

SOURCE_URL="https://github.com/${GITHUB_REPO}/archive/${GITHUB_COMMIT}.tar.gz"
SOURCE_FILE="${PKGNAME}-${PKGVER}.tar.gz"
WORK_DIR="$(mktemp -d "/tmp/${PKGNAME}-aur.XXXXXX")"
SOURCE_DIR="$WORK_DIR/source"
AUR_DIR="$WORK_DIR/aur"
mkdir -p "$SOURCE_DIR"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "==> Version: v${PKGVER}"
echo "==> GitHub commit: ${GITHUB_COMMIT}"
echo "==> Downloading the already-published source from GitHub"
curl -fL --retry 3 --retry-delay 2 \
    -o "$SOURCE_DIR/$SOURCE_FILE" \
    "$SOURCE_URL"

SHA256="$(sha256sum "$SOURCE_DIR/$SOURCE_FILE" | awk '{print $1}')"
tar -tzf "$SOURCE_DIR/$SOURCE_FILE" > "$SOURCE_DIR/archive.list"
ARCHIVE_ROOT="$(awk -F/ 'NF {print $1; exit}' "$SOURCE_DIR/archive.list")"
TEMPLATE_PATH="${ARCHIVE_ROOT}/packaging/PKGBUILD.template"

[[ -n "$ARCHIVE_ROOT" ]] || {
    echo "ERROR: could not determine the GitHub archive root." >&2
    exit 1
}

grep -Fx "$TEMPLATE_PATH" "$SOURCE_DIR/archive.list" >/dev/null || {
    echo "ERROR: packaging/PKGBUILD.template is missing from the GitHub source." >&2
    exit 1
}

tar -xOzf "$SOURCE_DIR/$SOURCE_FILE" "$TEMPLATE_PATH" > "$SOURCE_DIR/PKGBUILD.template"

escape_sed() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

render_pkgbuild() {
    sed \
        -e "s|@PKGVER@|$(escape_sed "$PKGVER")|g" \
        -e "s|@PKGREL@|$(escape_sed "$PKGREL")|g" \
        -e "s|@GITHUB_REPO@|$(escape_sed "$GITHUB_REPO")|g" \
        -e "s|@GITHUB_COMMIT@|$(escape_sed "$GITHUB_COMMIT")|g" \
        -e "s|@ARCHIVE_ROOT@|$(escape_sed "$ARCHIVE_ROOT")|g" \
        -e "s|@SHA256@|$(escape_sed "$SHA256")|g" \
        "$SOURCE_DIR/PKGBUILD.template"
}

echo "==> Cloning the AUR repository"
git clone "$AUR_REPO" "$AUR_DIR"
render_pkgbuild > "$AUR_DIR/PKGBUILD"

cd "$AUR_DIR"
makepkg --printsrcinfo > .SRCINFO
SRCDEST="$SOURCE_DIR" makepkg --verifysource --noconfirm
SRCDEST="$SOURCE_DIR" makepkg -f --clean --noconfirm

PKGFILE="$(find . -maxdepth 1 -type f -name "${PKGNAME}-${PKGVER}-${PKGREL}-any.pkg.tar.*" -print -quit)"
[[ -n "$PKGFILE" ]] || {
    echo "ERROR: the package archive was not created." >&2
    exit 1
}

bsdtar -tf "$PKGFILE" > "$SOURCE_DIR/package.list"
grep -F 'usr/share/kwin/effects/kwin4_effect_burning_windows/metadata.json' "$SOURCE_DIR/package.list" >/dev/null
grep -F 'usr/share/kwin/effects/kwin4_effect_burning_windows/contents/code/main.js' "$SOURCE_DIR/package.list" >/dev/null
grep -F 'usr/share/kwin/effects/kwin4_effect_burning_windows/contents/shaders/burn_core.frag' "$SOURCE_DIR/package.list" >/dev/null
rm -f -- ./*.pkg.tar.*

git add PKGBUILD .SRCINFO
if git diff --cached --quiet; then
    echo "==> AUR is already up to date; nothing to publish."
    exit 0
fi

git commit -m "v${PKGVER}"
git push origin HEAD:master

echo "==> Published ${PKGNAME} ${PKGVER}-${PKGREL} to AUR."
