#!/usr/bin/env bash
set -euo pipefail

APP_NAME="kwin6-effect-remisa-burn"
VERSION="0.1.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"

cat <<MSG
Installing ${APP_NAME} ${VERSION} external-native-safe26

This keeps the safe25 burn effect and adds a user-facing Desktop Effects toggle:
  Settings => Desktop Effects => Burning Windows

Author: Remisa Phillips

The visible "Burning Windows" entry is a no-op KWin package used only as a checkbox.
The real native backend remains: remisa_burn

Restart the computer after installation.
MSG

cat > "$ROOT_DIR/rescue-remisa.sh" <<'RESCUE'
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
echo "Remisa Burn / Burning Windows removed. Restart the computer."
RESCUE
chmod +x "$ROOT_DIR/rescue-remisa.sh"

echo
echo "[1/5] Installing/checking Arch build dependencies..."
sudo pacman -S --needed base-devel cmake extra-cmake-modules qt6-base qt6-tools kwin

echo
echo "[2/5] Removing stale/broken experiment files..."
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

# Avoid conflict with built-in close effects.
kwriteconfig6 --file kwinrc --group Plugins --key fallapartEnabled false || true
kwriteconfig6 --file kwinrc --group Plugins --key glideEnabled false || true
kbuildsycoca6 --noincremental || true

echo
echo "[3/5] Configuring..."
rm -rf "$BUILD_DIR"
cmake -S "$ROOT_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr

echo
echo "[4/5] Building..."
cmake --build "$BUILD_DIR" --parallel "$(nproc)"

echo
echo "[5/5] Installing native backend and Desktop Effects toggle..."
sudo cmake --install "$BUILD_DIR"

INSTALLED="/usr/lib/qt6/plugins/kwin/effects/plugins/remisa_burn.so"
TOGGLE_META="/usr/share/kwin/effects/burning_windows/metadata.json"
TOGGLE_QML="/usr/share/kwin/effects/burning_windows/contents/ui/main.qml"

if [[ ! -f "$INSTALLED" ]]; then
    echo "ERROR: expected native backend not found: $INSTALLED" >&2
    exit 1
fi
if [[ ! -f "$TOGGLE_META" ]]; then
    echo "ERROR: expected Desktop Effects metadata not found: $TOGGLE_META" >&2
    exit 1
fi
if [[ ! -f "$TOGGLE_QML" ]]; then
    echo "ERROR: expected Desktop Effects no-op QML not found: $TOGGLE_QML" >&2
    exit 1
fi

# The backend must stay loaded. The visible checkbox controls burning_windowsEnabled.
kwriteconfig6 --file kwinrc --group Plugins --key remisa_burnEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key burning_windowsEnabled true
kbuildsycoca6 --noincremental || true

cat <<MSG

Installed successfully:
  $INSTALLED
  $TOGGLE_META
  $TOGGLE_QML

Restart the computer now.

After reboot, use:
  Settings => Desktop Effects => Burning Windows

to enable/disable the effect without restart.
MSG
