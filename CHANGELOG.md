# Changelog

## 0.1.1

- Replaced the private-ABI C++ KWin module with a public KWin JavaScript scripted effect.
- Removed all compilation and KWin development-header requirements.
- Moved the burn shader into the standard KWin effect package layout.
- Added GLSL 1.10 and GLSL 1.40 shader variants.
- Added an opacity fallback when custom shader creation is unavailable.
- Declared the JavaScript entry point with `X-Plasma-MainScript` and moved to the canonical `kwin4_effect_burning_windows` plugin id.
- Declared KWin's standard exclusive open/close animation category.
- Reworked manual installation, uninstallation, migration, validation, and AUR publishing.
- Clarified migration from 0.1.0 when its legacy uninstaller deleted files but left an AUR/pacman package record installed.
- Simplified `aur.sh` to a zero-argument publisher that assumes the release commit has already been pushed to GitHub.
- Changed the AUR package architecture to `any` and reduced runtime dependencies to `kwin>=6.0`.

## 0.1.0

- Initial release.
