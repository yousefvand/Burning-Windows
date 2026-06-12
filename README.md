# Burning Windows

**Burning Windows** is a native KWin effect for **KDE Plasma 6 on Wayland**. It adds a burning animation when normal application windows are closed.

![Burning Windows demo](demo.png)

## Features

- Bottom-to-top burning close animation
- Transparent burned area, so the desktop or windows behind remain visible
- Works with normal decorated windows and fullscreen application windows
- Skips popups, menus, dialogs, Plasma/internal windows, panels, and other special windows
- Toggle available in:

```text
System Settings → Desktop Effects → Burning Windows
```

- No KWin source patching required
- No compositor replacement required
- Native KWin effect backend with a small Desktop Effects toggle package

## Requirements

- Arch Linux or Arch-based distribution
- KDE Plasma 6
- KWin 6
- Wayland session
- Qt 6
- CMake and KDE development tools for building from source

Recommended packages for building manually:

```bash
sudo pacman -S --needed base-devel cmake extra-cmake-modules qt6-base qt6-tools kwin
```

## Installation from AUR

```bash
yay -S burning-windows
```

After the first installation, reboot once. Then enable the effect from:

```text
System Settings → Desktop Effects → Burning Windows
```

After that, enabling and disabling the effect from Desktop Effects does not require a restart.

## Manual installation

From the project root:

```bash
./install.sh
```

Then reboot once.

## Uninstallation

From the project root:

```bash
./uninstall.sh
```

Then reboot once.

## Technical notes

Burning Windows uses a native KWin effect backend with the internal effect id:

```text
remisa_burn
```

The visible Desktop Effects entry is named:

```text
Burning Windows
```

The effect is designed for Plasma 6 Wayland. X11 is not a target for this project.

## Troubleshooting

Check whether KWin can see the native effect:

```bash
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.listOfEffects | grep -i remisa
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectSupported remisa_burn
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded remisa_burn
```

Expected result:

```text
remisa_burn
true
true
```

Check logs:

```bash
journalctl --user -b | grep -i "Remisa Burn\|Burning Windows\|remisa"
```

If the effect was just installed and does not appear yet, reboot once.

## License

MIT License.

