#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$ROOT_DIR/package"
EFFECT_ID="kwin4_effect_burning_windows"
LEGACY_EFFECT_ID="burning_windows"

command -v kpackagetool6 >/dev/null 2>&1 || {
    echo "ERROR: kpackagetool6 was not found. Install KDE Frameworks/KPackage first." >&2
    exit 1
}

if command -v pacman >/dev/null 2>&1 && pacman -Q burning-windows >/dev/null 2>&1; then
    installed_package="$(pacman -Q burning-windows)"
    cat >&2 <<MSG
ERROR: pacman still has this package registered:
  ${installed_package}

The 0.1.0 uninstall script removed the installed effect files directly, but it
could not remove pacman's package-database entry. Deleting files is therefore
not the same as uninstalling an AUR package.

Choose one installation route:

  Upgrade the pacman/AUR package:
    yay -S burning-windows

  Or remove the registered package before a per-user test installation:
    sudo pacman -R burning-windows
    ./install.sh

The installer will not mix a pacman-managed package with files under ~/.local.
MSG
    exit 1
fi

# Remove both the broken 0.1.1 test package and any previous corrected install.
kpackagetool6 --type KWin/Effect --remove "$LEGACY_EFFECT_ID" >/dev/null 2>&1 || true
kpackagetool6 --type KWin/Effect --remove "$EFFECT_ID" >/dev/null 2>&1 || true
kpackagetool6 --type KWin/Effect --install "$PACKAGE_DIR"

# The old C++ backend must not be enabled after migration.
if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kwinrc --group Plugins --key remisa_burnEnabled false || true
    kwriteconfig6 --file kwinrc --group Plugins --key burning_windowsEnabled false || true
fi

# Clean only unowned legacy files created by the old manual installer.
legacy_files=(
    /usr/lib/qt6/plugins/kwin/effects/plugins/remisa_burn.so
    /usr/lib/qt6/plugins/kwin/plugins/remisa_burn.so
    /usr/lib/qt/plugins/kwin/effects/plugins/remisa_burn.so
)

for file in "${legacy_files[@]}"; do
    [[ -e "$file" ]] || continue
    if command -v pacman >/dev/null 2>&1 && pacman -Qo "$file" >/dev/null 2>&1; then
        echo "Keeping pacman-owned legacy file: $file"
    else
        echo "Removing legacy native plugin: $file"
        sudo rm -f "$file"
    fi
done

command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
command -v qdbus6 >/dev/null 2>&1 && qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

cat <<'MSG'

Burning Windows 0.1.1 was installed as a per-user KWin scripted effect.
Its KWin plugin id is kwin4_effect_burning_windows.
Enable it in:
  Open System Settings and search for: Animations
  Then choose Burning Windows for Window Open/Close Animation.

  Or open the page directly:
    kcmshell6 kcm_animations

On Plasma 6.4 and later, this class of effect is intentionally not listed on
the Desktop Effects page.

When migrating from version 0.1.0, log out and back in once so KWin unloads
the old native remisa_burn module. Later KWin updates do not require rebuilding
or reinstalling this version.
MSG
