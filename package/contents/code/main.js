/*
 * Burning Windows 0.1.1
 * SPDX-FileCopyrightText: 2026 Remisa Phillips
 * SPDX-License-Identifier: MIT
 */

"use strict";

const BURN_DURATION_MS = 780;

class BurningWindowsEffect {
    constructor() {
        this.duration = animationTime(BURN_DURATION_MS);
        this.shaderId = this.loadShader();

        effects.windowClosed.connect(this.onWindowClosed.bind(this));
        effects.windowDataChanged.connect(this.onWindowDataChanged.bind(this));
    }

    loadShader() {
        try {
            return effect.addFragmentShader(Effect.MapTexture, "burn.frag");
        } catch (error) {
            print("Burning Windows: custom shader could not be loaded; using opacity fallback:", error);
            return 0;
        }
    }

    static isEligibleWindow(window) {
        if (!window || !window.managed || !window.visible || window.outline) {
            return false;
        }

        if (window.specialWindow || window.popupWindow || window.popupMenu || window.dialog) {
            return false;
        }

        // Do not compete with an effect that has already claimed this close event.
        if (window.deleted && effect.isGrabbed(window, Effect.WindowClosedGrabRole)) {
            return false;
        }

        // Fullscreen app windows often have no decoration, but remain normal windows.
        return window.normalWindow || window.hasDecoration;
    }

    onWindowClosed(window) {
        if (effects.hasActiveFullScreenEffect) {
            return;
        }

        if (window.skipsCloseAnimation || !BurningWindowsEffect.isEligibleWindow(window)) {
            return;
        }

        if (window.burningWindowsAnimation) {
            cancel(window.burningWindowsAnimation);
            delete window.burningWindowsAnimation;
        }

        if (this.shaderId !== 0) {
            // Use the positional API deliberately. It is part of ScriptedEffect's
            // public interface and avoids depending on private C++ effect classes.
            window.burningWindowsAnimation = effect.animate(
                window,
                Effect.Shader,
                this.duration,
                1.0,
                0.0,
                0,
                QEasingCurve.Linear,
                0,
                false,
                true,
                this.shaderId
            );
        } else {
            // A conservative fallback keeps close behavior graceful on a compositor
            // where a custom OpenGL fragment shader cannot be created.
            window.burningWindowsAnimation = effect.animate(
                window,
                Effect.Opacity,
                this.duration,
                0.0,
                1.0,
                0,
                QEasingCurve.InCubic,
                0,
                false,
                true
            );
        }
    }

    onWindowDataChanged(window, role) {
        if (role !== Effect.WindowClosedGrabRole) {
            return;
        }

        if (effect.isGrabbed(window, Effect.WindowClosedGrabRole) && window.burningWindowsAnimation) {
            cancel(window.burningWindowsAnimation);
            delete window.burningWindowsAnimation;
        }
    }
}

new BurningWindowsEffect();
