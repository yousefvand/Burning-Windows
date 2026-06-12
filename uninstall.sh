#!/usr/bin/env bash
set -euo pipefail

for id in remisa_burn kwin4_effect_remisa_burn kwin6_effect_remisa_burn burning_windows; do
    kwriteconfig6 --file kwinrc --group Plugins --key "${id}Enabled" false || true
    sudo rm -f "/usr/lib/qt6/plugins/kwin/effects/plugins/${id}.so"
    sudo rm -f "/usr/lib/qt6/plugins/kwin/plugins/${id}.so"
    sudo rm -f "/usr/lib/qt/plugins/kwin/effects/plugins/${id}.so"
    sudo rm -f "/usr/share/kwin/builtin-effects/${id}.json"
    sudo rm -f "/usr/share/kwin-wayland/builtin-effects/${id}.json"
    sudo rm -f "/usr/share/kservices6/kwin/${id}.desktop"
    sudo rm -rf "/usr/share/kwin/effects/${id}"
    sudo rm -rf "/usr/share/kwin-wayland/effects/${id}"
done
kbuildsycoca6 --noincremental || true

echo "Removed Remisa Burn / Burning Windows. Restart the computer."
