#!/usr/bin/env bash
set -euo pipefail

PKGNAME="burning-windows"
GITHUB_REPO="yousefvand/Burning-Windows"
AUR_REPO="ssh://aur@aur.archlinux.org/${PKGNAME}.git"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

for cmd in git sed awk grep makepkg bsdtar find; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: $cmd is required." >&2
        exit 1
    }
done

[[ -d .git ]] || {
    echo "ERROR: aur.sh must be run from the Burning-Windows Git repository." >&2
    exit 1
}

# Expected workflow:
#   git commit -m "v0.1.1"
#   git push
#   ./aur.sh
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

# GitHub is managed outside this script. Verify only that HEAD is already pushed.
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

METADATA_VERSION="$(
    sed -n 's/.*"Version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        package/metadata.json | head -n 1
)"

if [[ "$METADATA_VERSION" != "$PKGVER" ]]; then
    echo "ERROR: package/metadata.json is version ${METADATA_VERSION:-unknown}, but the latest commit is v${PKGVER}." >&2
    exit 1
fi

TEMPLATE="$ROOT_DIR/packaging/PKGBUILD.template"
[[ -f "$TEMPLATE" ]] || {
    echo "ERROR: packaging/PKGBUILD.template is missing." >&2
    exit 1
}

WORK_DIR="$(mktemp -d "/tmp/${PKGNAME}-aur.XXXXXX")"
AUR_DIR="$WORK_DIR/aur"
BUILD_DIR="$WORK_DIR/build"
VALIDATION_DIR="$WORK_DIR/validation"
mkdir -p "$BUILD_DIR" "$VALIDATION_DIR"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "==> Version: v${PKGVER}"
echo "==> GitHub commit: ${GITHUB_COMMIT}"
echo "==> Cloning the AUR repository"
git clone "$AUR_REPO" "$AUR_DIR"

existing_pkgver="$(sed -n 's/^pkgver=//p' "$AUR_DIR/PKGBUILD" 2>/dev/null | head -n 1 || true)"
existing_pkgrel="$(sed -n 's/^pkgrel=//p' "$AUR_DIR/PKGBUILD" 2>/dev/null | head -n 1 || true)"
existing_commit="$(
    sed -n \
        -e "s/^_source_commit=['\"]\([^'\"]*\)['\"]$/\1/p" \
        -e "s/^_commit=['\"]\([^'\"]*\)['\"]$/\1/p" \
        "$AUR_DIR/PKGBUILD" 2>/dev/null | head -n 1 || true
)"

if [[ "$existing_pkgver" == "$PKGVER" && "$existing_commit" == "$GITHUB_COMMIT" ]]; then
    echo "==> AUR already points to GitHub commit ${GITHUB_COMMIT}; nothing to publish."
    exit 0
fi

if [[ "$existing_pkgver" == "$PKGVER" && "$existing_pkgrel" =~ ^[0-9]+$ ]]; then
    PKGREL="$((existing_pkgrel + 1))"
else
    PKGREL="1"
fi

echo "==> AUR package release: ${PKGVER}-${PKGREL}"

escape_sed() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

sed \
    -e "s|@PKGVER@|$(escape_sed "$PKGVER")|g" \
    -e "s|@PKGREL@|$(escape_sed "$PKGREL")|g" \
    -e "s|@GITHUB_REPO@|$(escape_sed "$GITHUB_REPO")|g" \
    -e "s|@GITHUB_COMMIT@|$(escape_sed "$GITHUB_COMMIT")|g" \
    "$TEMPLATE" > "$AUR_DIR/PKGBUILD"

if grep -qE '@[A-Z0-9_]+@' "$AUR_DIR/PKGBUILD"; then
    echo "ERROR: unresolved placeholder in generated PKGBUILD:" >&2
    grep -nE '@[A-Z0-9_]+@' "$AUR_DIR/PKGBUILD" >&2
    exit 1
fi

cd "$AUR_DIR"

# Remove source archives that older package revisions committed to AUR.
while IFS= read -r old_source; do
    [[ -n "$old_source" ]] || continue
    git rm -f -- "$old_source"
done < <(git ls-files "${PKGNAME}-*.tar.gz" "${PKGNAME}-*.zip")

makepkg --printsrcinfo > .SRCINFO

# Build outside the AUR repository. VCS source caches, src/, pkg/, and package
# archives must never be created or staged inside an AUR Git repository.
cp "$AUR_DIR/PKGBUILD" "$BUILD_DIR/PKGBUILD"
cd "$BUILD_DIR"
makepkg -f --clean --noconfirm

PKGFILE="$(
    find "$BUILD_DIR" -maxdepth 1 -type f \
        -name "${PKGNAME}-${PKGVER}-${PKGREL}-any.pkg.tar.*" \
        -print -quit
)"
[[ -n "$PKGFILE" ]] || {
    echo "ERROR: the package archive was not created." >&2
    exit 1
}

bsdtar -tf "$PKGFILE" > "$VALIDATION_DIR/package.list"
grep -F 'usr/share/kwin/effects/kwin4_effect_burning_windows/metadata.json' "$VALIDATION_DIR/package.list" >/dev/null
grep -F 'usr/share/kwin/effects/kwin4_effect_burning_windows/contents/code/main.js' "$VALIDATION_DIR/package.list" >/dev/null
grep -F 'usr/share/kwin/effects/kwin4_effect_burning_windows/contents/shaders/burn_core.frag' "$VALIDATION_DIR/package.list" >/dev/null

cd "$AUR_DIR"

# Stage only tracked changes/deletions plus the two allowed package metadata files.
# Never stage untracked makepkg artifacts.
git add -u
git add -- PKGBUILD .SRCINFO

if git diff --cached --name-only | grep -q '/'; then
    echo "ERROR: refusing to publish: the AUR commit contains a subdirectory." >&2
    git diff --cached --name-only >&2
    exit 1
fi

if git diff --cached --quiet; then
    echo "==> AUR is already up to date; nothing to publish."
    exit 0
fi

git commit -m "v${PKGVER}-${PKGREL}"
git push origin HEAD:master

echo "==> Published ${PKGNAME} ${PKGVER}-${PKGREL} to AUR."
