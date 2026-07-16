#!/usr/bin/env bash
set -euo pipefail

EFFECT_ID="kwin4_effect_burning_windows"
LEGACY_EFFECT_ID="burning_windows"

if command -v pacman >/dev/null 2>&1 && pacman -Q burning-windows >/dev/null 2>&1; then
    cat >&2 <<'MSG'
ERROR: The AUR package 'burning-windows' is installed.
Remove it with your package manager, for example: sudo pacman -Rns burning-windows
MSG
    exit 1
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 --type KWin/Effect --remove "$EFFECT_ID" || true
    kpackagetool6 --type KWin/Effect --remove "$LEGACY_EFFECT_ID" || true
else
    rm -rf "$HOME/.local/share/kwin/effects/$EFFECT_ID"
    rm -rf "$HOME/.local/share/kwin/effects/$LEGACY_EFFECT_ID"
fi

if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_burning_windowsEnabled false || true
    kwriteconfig6 --file kwinrc --group Plugins --key burning_windowsEnabled false || true
    kwriteconfig6 --file kwinrc --group Plugins --key remisa_burnEnabled false || true
fi

command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
command -v qdbus6 >/dev/null 2>&1 && qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

echo "Burning Windows was removed. Log out and back in if it is still loaded in the current KWin session."
