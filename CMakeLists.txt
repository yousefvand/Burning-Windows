cmake_minimum_required(VERSION 3.16)

project(burning-windows VERSION 0.1.1 LANGUAGES NONE)


# This project is a KWin scripted-effect package. It intentionally builds no
# C++ module and therefore has no dependency on KWin's private C++ ABI.
install(
    DIRECTORY package/
    DESTINATION "share/kwin/effects/kwin4_effect_burning_windows"
)
