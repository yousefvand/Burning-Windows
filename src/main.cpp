/*
 * Remisa Burn 0.1.0 - external-native-safe26 AnimationEffect refined bounded burn shader KWin effect
 * SPDX-FileCopyrightText: 2026 Remisa Phillips
 * SPDX-License-Identifier: MIT
 */

#include "remisaburn.h"

#include <effect/effect.h>

namespace KWin
{

KWIN_EFFECT_FACTORY_SUPPORTED_ENABLED(
    RemisaBurnEffect,
    "metadata.json",
    return RemisaBurnEffect::supported();,
    return RemisaBurnEffect::enabledByDefault();)

} // namespace KWin

#include "main.moc"
