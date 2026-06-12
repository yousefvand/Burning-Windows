/*
 * Remisa Burn 0.1.0 - external-native-safe26 AnimationEffect stronger in-place burn shader test
 * SPDX-FileCopyrightText: 2026 Remisa Phillips
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <effect/animationeffect.h>

#include <memory>

namespace KWin
{

class GLShader;

class RemisaBurnEffect : public AnimationEffect
{
    Q_OBJECT

public:
    explicit RemisaBurnEffect();
    ~RemisaBurnEffect() override;

    void reconfigure(ReconfigureFlags flags) override;
    void genericAnimation(EffectWindow *window, WindowPaintData &data, float progress, uint meta) override;

    static bool supported();
    static bool enabledByDefault();

private Q_SLOTS:
    void slotWindowClosed(KWin::EffectWindow *window);

private:
    void initShader();
    bool isBurningWindowsToggleEnabled() const;
    bool shouldBurnWindow(KWin::EffectWindow *window) const;

    std::unique_ptr<GLShader> m_burnShader;
};

} // namespace KWin
