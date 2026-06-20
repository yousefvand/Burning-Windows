/*
 * Remisa Burn 0.1.0 - external-native-safe26 AnimationEffect corrected bottom-to-top transparent burn shader test
 * SPDX-FileCopyrightText: 2026 Remisa Phillips
 * SPDX-License-Identifier: MIT
 */

#include "remisaburn.h"

#include <effect/effecthandler.h>
#include <opengl/glshader.h>
#include <opengl/glshadermanager.h>

#include <QDebug>
#include <QEasingCurve>
#include <QSettings>
#include <QStandardPaths>

#include <chrono>

namespace KWin
{

static constexpr int BurnFoundationDurationMs = 780;
static constexpr auto BurnFoundationDuration = std::chrono::milliseconds{BurnFoundationDurationMs};
static constexpr uint RemisaGenericMeta = 0x52;
static constexpr uint RemisaShaderMeta = 0x53;

RemisaBurnEffect::RemisaBurnEffect()
    : AnimationEffect()
{
    qInfo() << "Remisa Burn external-native-safe26 loaded: backend for Burning Windows toggle; bottom-to-top transparent burn; fullscreen-aware filter; no square particles; no manual grab";
    qInfo() << "Remisa Burn external-native-safe26: duration" << BurnFoundationDurationMs << "ms";

    initShader();

    if (effects) {
        // This connection is intentionally done in the constructor, as required by
        // KWin's AnimationEffect documentation for close-window animations.
        connect(effects, &EffectsHandler::windowClosed,
                this, &RemisaBurnEffect::slotWindowClosed);
        qInfo() << "Remisa Burn external-native-safe26: connected to windowClosed using AnimationEffect";
    } else {
        qWarning() << "Remisa Burn external-native-safe26: effects handler is null";
    }
}

RemisaBurnEffect::~RemisaBurnEffect()
{
    qInfo() << "Remisa Burn external-native-safe26 unloaded";
}

void RemisaBurnEffect::initShader()
{
    auto *manager = ShaderManager::instance();
    if (!manager) {
        qWarning() << "Remisa Burn external-native-safe26: ShaderManager is null; burn shader disabled";
        return;
    }

    // Corrected bottom-to-top burn shader visual tuning step.
    // KWin's AnimationEffect::Shader sets a float uniform named animationProgress.
    // The shader assumes KWin's generated MapTexture vertex shader provides texcoord0
    // and that the source texture sampler is named sampler, matching KWin's own texture shaders.
    static const QByteArray fragmentSource = QByteArrayLiteral(R"SHADER(
#version 140

uniform sampler2D sampler;
uniform float animationProgress;

in vec2 texcoord0;
out vec4 fragColor;

float remisaHash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float remisaNoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = remisaHash(i);
    float b = remisaHash(i + vec2(1.0, 0.0));
    float c = remisaHash(i + vec2(0.0, 1.0));
    float d = remisaHash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float remisaFbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;
    v += a * remisaNoise(p); p *= 2.03; a *= 0.5;
    v += a * remisaNoise(p); p *= 2.07; a *= 0.5;
    v += a * remisaNoise(p);
    return v;
}

void main()
{
    vec4 c = texture(sampler, texcoord0);
    float p = clamp(animationProgress, 0.0, 1.0);

    // Bottom-to-top burn frontier. On this KWin build texcoord0.y is oriented
    // opposite to the first shader assumption. Use texcoord0.y directly so the
    // consumed transparent area starts at the bottom and moves upward.
    float y = texcoord0.y;

    float coarse = remisaFbm(vec2(texcoord0.x * 9.0, p * 3.5));
    float fine = remisaFbm(vec2(texcoord0.x * 42.0, y * 9.0 + p * 15.0));

    // More irregular than safe10, but still bounded inside the texture.
    float waviness = (coarse - 0.5) * 0.095 + (fine - 0.5) * 0.035;
    float front = clamp(p + waviness, -0.08, 1.08);
    float d = y - front;

    // Consumed area below the frontier is genuinely transparent.
    float windowAlpha = smoothstep(-0.012, 0.070, d);

    // Stronger flame band: visible core plus taller but bounded tongues rising
    // into the unburned area. This should feel like fire rather than a weak line.
    float core = 1.0 - smoothstep(0.000, 0.032, abs(d));
    float tongueHeight = 0.080 + 0.135 * coarse;
    float tongues = (1.0 - smoothstep(0.000, tongueHeight, d)) * smoothstep(-0.030, 0.020, d);
    float holes = smoothstep(0.18, 0.82, fine);
    tongues *= mix(0.55, 1.25, holes);

    // Glow just above the flame, kept alpha-light so it does not become a white box.
    float glow = (1.0 - smoothstep(0.000, 0.180, max(d, 0.0))) * smoothstep(-0.035, 0.010, d);

    // Ash/dissolve eats into the surviving window near the frontier.
    float ashNoise = remisaFbm(vec2(texcoord0.x * 85.0, y * 55.0 + p * 23.0));
    float ashBand = (1.0 - smoothstep(0.040, 0.220, d)) * smoothstep(0.010, 0.090, d);
    // Smooth ash dissolve only. Do not use floor/step point noise here; it appears
    // as square particles at the bottom of the flame on KWin/Wayland.
    float ashCut = ashBand * smoothstep(0.60, 0.92, ashNoise) * 0.55;

    float flame = clamp(max(core * 1.35, tongues), 0.0, 1.25);

    vec3 deepRed = vec3(0.60, 0.015, 0.000);
    vec3 red = vec3(1.00, 0.060, 0.000);
    vec3 orange = vec3(1.00, 0.330, 0.015);
    vec3 yellow = vec3(1.00, 0.830, 0.110);
    vec3 whiteHot = vec3(1.00, 0.970, 0.600);

    vec3 flameColor = mix(deepRed, red, smoothstep(0.05, 0.25, flame));
    flameColor = mix(flameColor, orange, smoothstep(0.22, 0.55, flame));
    flameColor = mix(flameColor, yellow, smoothstep(0.45, 0.82, flame));
    flameColor = mix(flameColor, whiteHot, core * 0.85);

    // Heat tint near the frontier plus visible flame. Keep transparent areas transparent.
    vec3 heated = c.rgb;
    heated = mix(heated, vec3(1.0, 0.27, 0.02), glow * 0.35);
    heated = mix(heated, flameColor, clamp(flame * 0.90, 0.0, 1.0));
    heated += flameColor * core * 0.30;

    float alpha = c.a * windowAlpha * (1.0 - ashCut);
    alpha = max(alpha, c.a * clamp(flame * 0.96 + glow * 0.28, 0.0, 1.0));
    alpha = clamp(alpha, 0.0, c.a);

    // KWin compositing expects premultiplied alpha here; non-premultiplied
    // bright RGB with low alpha can show as a white rectangle instead of
    // revealing the scene behind the burned window.
    heated = mix(vec3(0.0), heated, step(0.001, alpha));
    fragColor = vec4(heated * alpha, alpha);
}
)SHADER");

    m_burnShader = manager->generateCustomShader(ShaderTraits(ShaderTrait::MapTexture), QByteArray(), fragmentSource);
    if (!m_burnShader) {
        qWarning() << "Remisa Burn external-native-safe26: burn shader is invalid; falling back to safe non-shader animation";
        m_burnShader.reset();
        return;
    }

    qInfo() << "Remisa Burn external-native-safe26: burn shader created and valid";
}

void RemisaBurnEffect::reconfigure(ReconfigureFlags flags)
{
    AnimationEffect::reconfigure(flags);
    qInfo() << "Remisa Burn external-native-safe26 reconfigured";
}

bool RemisaBurnEffect::isBurningWindowsToggleEnabled() const
{
    const QString configPath = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/kwinrc");
    QSettings settings(configPath, QSettings::IniFormat);
    settings.beginGroup(QStringLiteral("Plugins"));
    const bool enabled = settings.value(QStringLiteral("burning_windowsEnabled"), true).toBool();
    settings.endGroup();
    return enabled;
}

bool RemisaBurnEffect::shouldBurnWindow(KWin::EffectWindow *window) const
{
    if (!window) {
        return false;
    }

    // User-facing Desktop Effects checkbox. The visible KCM entry is a tiny
    // no-op KPackage named "Burning Windows". The native effect remains loaded
    // as remisa_burn and reads that checkbox on every close event, so enabling
    // or disabling it in System Settings works without restarting KWin.
    if (!isBurningWindowsToggleEnabled()) {
        return false;
    }

    // Safe26 keeps the safe22/safe24 visual effect but fixes fullscreen app windows.
    // Fullscreen app windows often report hasDecoration() == false because the
    // titlebar is hidden while fullscreen. They are still normal closeable app
    // windows, so accept either:
    //   - decorated normal-style windows, or
    //   - normal windows without decoration, such as fullscreen app windows.
    // Still reject Plasma/internal/special windows, dialogs, popups, and menus.
    if (window->isSpecialWindow()) {
        return false;
    }
    if (window->isPopupWindow() || window->isPopupMenu()) {
        return false;
    }
    if (window->isDialog()) {
        return false;
    }

    if (window->hasDecoration()) {
        return true;
    }

    if (window->isNormalWindow()) {
        return true;
    }

    return false;
}


void RemisaBurnEffect::slotWindowClosed(KWin::EffectWindow *window)
{
    if (!window) {
        qInfo() << "Remisa Burn external-native-safe26: windowClosed null window; skipped";
        return;
    }

    if (!shouldBurnWindow(window)) {
        qInfo() << "Remisa Burn external-native-safe26: skipped special/popup/dialog/non-normal window" << window;
        return;
    }

    qInfo() << "Remisa Burn external-native-safe26: windowClosed eligible decorated window" << window;

    quint64 shaderId = 0;
    quint64 fallbackScaleId = 0;
    quint64 fallbackOpacityId = 0;

    const quint64 genericId = animate(window,
                                      AnimationEffect::Generic,
                                      RemisaGenericMeta,
                                      BurnFoundationDuration,
                                      FPx2(1.0),
                                      QEasingCurve::Linear,
                                      0,
                                      FPx2(0.0),
                                      false,
                                      true);

    if (m_burnShader) {
        // Safe22 deliberately lets the shader do the consumption instead of
        // shrinking the whole window. This should feel more like burning.
        shaderId = animate(window,
                           AnimationEffect::Shader,
                           RemisaShaderMeta,
                           BurnFoundationDuration,
                           FPx2(1.0),
                           QEasingCurve::Linear,
                           0,
                           FPx2(0.0),
                           false,
                           true,
                           m_burnShader.get());
    } else {
        // Conservative fallback to the last proven non-shader behavior.
        uint scaleMeta = 0;
        setMetaData(AnimationEffect::SourceAnchor, AnimationEffect::Top | AnimationEffect::Horizontal, scaleMeta);
        setMetaData(AnimationEffect::TargetAnchor, AnimationEffect::Top | AnimationEffect::Horizontal, scaleMeta);

        fallbackScaleId = animate(window,
                                  AnimationEffect::Scale,
                                  scaleMeta,
                                  BurnFoundationDuration,
                                  FPx2(1.0, 0.02),
                                  QEasingCurve::InCubic,
                                  0,
                                  FPx2(1.0, 1.0),
                                  false,
                                  true);

        fallbackOpacityId = animate(window,
                                    AnimationEffect::Opacity,
                                    0,
                                    BurnFoundationDuration,
                                    FPx2(0.0),
                                    QEasingCurve::InCubic,
                                    0,
                                    FPx2(1.0),
                                    false,
                                    true);
    }

    qInfo() << "Remisa Burn external-native-safe26: generic paint-hook animation id" << genericId;
    if (shaderId != 0) {
        qInfo() << "Remisa Burn external-native-safe26: burn shader animation id" << shaderId;
        qInfo() << "Remisa Burn external-native-safe26: Burning Windows backend active; shader-only bottom-to-top burn; premultiplied transparent consumed area";
    } else {
        qInfo() << "Remisa Burn external-native-safe26: burn shader animation skipped; fallback scale id" << fallbackScaleId << "fallback opacity id" << fallbackOpacityId;
    }
}

void RemisaBurnEffect::genericAnimation(EffectWindow *window, WindowPaintData &data, float progress, uint meta)
{
    Q_UNUSED(window)
    Q_UNUSED(data)
    Q_UNUSED(progress)
    Q_UNUSED(meta)

    // Still deliberately no-op. The visual change in safe26 is handled by
    // AnimationEffect::Shader if the burn shader is valid.
}

bool RemisaBurnEffect::supported()
{
    return true;
}

bool RemisaBurnEffect::enabledByDefault()
{
    return false;
}

} // namespace KWin
