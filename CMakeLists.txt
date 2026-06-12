cmake_minimum_required(VERSION 3.20)

project(kwin6-effect-remisa-burn VERSION 0.1.0 LANGUAGES CXX)

set(QT_MIN_VERSION "6.6.0")
set(KF_MIN_VERSION "6.0.0")
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(QT_DEFAULT_MAJOR_VERSION 6)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(FeatureSummary)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS Core Gui Widgets)
find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS CoreAddons I18n)

# Plasma 6 / KWin exports vary by distro build. Arch KWin 6.6.5 exports KWin::kwin.
find_package(KWin REQUIRED)

set(REMISA_KWIN_TARGET "")
foreach(candidate IN ITEMS KWin::kwin KWin::kwineffects kwin kwineffects)
    if(TARGET ${candidate})
        set(REMISA_KWIN_TARGET ${candidate})
        break()
    endif()
endforeach()

if(NOT REMISA_KWIN_TARGET)
    find_library(REMISA_KWIN_LIBRARY NAMES kwin kwineffects)
    if(REMISA_KWIN_LIBRARY)
        set(REMISA_KWIN_TARGET ${REMISA_KWIN_LIBRARY})
    endif()
endif()

if(NOT REMISA_KWIN_TARGET)
    message(FATAL_ERROR "Could not find a usable KWin library/target")
endif()

message(STATUS "Remisa Burn: using KWin link target/library: ${REMISA_KWIN_TARGET}")

add_subdirectory(src)
feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
