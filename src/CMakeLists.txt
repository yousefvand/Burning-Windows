add_library(remisa_burn MODULE
    main.cpp
    remisaburn.cpp
    remisaburn.h
)

set_target_properties(remisa_burn PROPERTIES
    PREFIX ""
    OUTPUT_NAME "remisa_burn"
    AUTOMOC ON
)

set_property(TARGET remisa_burn APPEND PROPERTY AUTOMOC_MACRO_NAMES
    KWIN_EFFECT_FACTORY
    KWIN_EFFECT_FACTORY_SUPPORTED
    KWIN_EFFECT_FACTORY_ENABLED
    KWIN_EFFECT_FACTORY_SUPPORTED_ENABLED
)

target_include_directories(remisa_burn PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    /usr/include/kwin
)

target_link_libraries(remisa_burn PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    KF6::CoreAddons
    KF6::I18n
    ${REMISA_KWIN_TARGET}
)

# External native Plasma 6 KWin effects are installed here, not builtin-effects.
# This matches maintained external C++ effects such as Better Blur.
install(TARGETS remisa_burn
    LIBRARY DESTINATION ${KDE_INSTALL_PLUGINDIR}/kwin/effects/plugins
)

# User-facing Desktop Effects checkbox package. It is a no-op declarative
# package named "Burning Windows". The native remisa_burn backend reads the
# burning_windowsEnabled key controlled by this package.
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/kpackage/burning_windows
    DESTINATION ${KDE_INSTALL_DATADIR}/kwin/effects
)
