#version 140

/*
 * Burning Windows 0.1.1 — GLSL 1.40 core variant
 * SPDX-FileCopyrightText: 2026 Remisa Phillips
 * SPDX-License-Identifier: MIT
 */

uniform sampler2D sampler;
uniform float animationProgress;

in vec2 texcoord0;
out vec4 fragColor;

float burnHash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float burnNoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = burnHash(i);
    float b = burnHash(i + vec2(1.0, 0.0));
    float c = burnHash(i + vec2(0.0, 1.0));
    float d = burnHash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float burnFbm(vec2 p)
{
    float v = 0.0;
    float a = 0.5;
    v += a * burnNoise(p); p *= 2.03; a *= 0.5;
    v += a * burnNoise(p); p *= 2.07; a *= 0.5;
    v += a * burnNoise(p);
    return v;
}

void main()
{
    vec4 source = texture(sampler, texcoord0);
    float progress = clamp(animationProgress, 0.0, 1.0);
    float y = texcoord0.y;

    float coarse = burnFbm(vec2(texcoord0.x * 9.0, progress * 3.5));
    float fine = burnFbm(vec2(texcoord0.x * 42.0, y * 9.0 + progress * 15.0));

    float waviness = (coarse - 0.5) * 0.095 + (fine - 0.5) * 0.035;
    float front = clamp(progress + waviness, -0.08, 1.08);
    float distanceToFront = y - front;

    float windowAlpha = smoothstep(-0.012, 0.070, distanceToFront);

    float core = 1.0 - smoothstep(0.000, 0.032, abs(distanceToFront));
    float tongueHeight = 0.080 + 0.135 * coarse;
    float tongues = (1.0 - smoothstep(0.000, tongueHeight, distanceToFront))
                  * smoothstep(-0.030, 0.020, distanceToFront);
    float holes = smoothstep(0.18, 0.82, fine);
    tongues *= mix(0.55, 1.25, holes);

    float glow = (1.0 - smoothstep(0.000, 0.180, max(distanceToFront, 0.0)))
               * smoothstep(-0.035, 0.010, distanceToFront);

    float ashNoise = burnFbm(vec2(texcoord0.x * 85.0, y * 55.0 + progress * 23.0));
    float ashBand = (1.0 - smoothstep(0.040, 0.220, distanceToFront))
                  * smoothstep(0.010, 0.090, distanceToFront);
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

    vec3 heated = source.rgb;
    heated = mix(heated, vec3(1.0, 0.27, 0.02), glow * 0.35);
    heated = mix(heated, flameColor, clamp(flame * 0.90, 0.0, 1.0));
    heated += flameColor * core * 0.30;

    float alpha = source.a * windowAlpha * (1.0 - ashCut);
    alpha = max(alpha, source.a * clamp(flame * 0.96 + glow * 0.28, 0.0, 1.0));
    alpha = clamp(alpha, 0.0, source.a);

    // KWin's window textures are composited with premultiplied alpha.
    heated = mix(vec3(0.0), heated, step(0.001, alpha));
    fragColor = vec4(heated * alpha, alpha);
}
