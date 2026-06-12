import QtQuick
import org.kde.kwin

// This package is intentionally invisible. It exists only so System Settings
// exposes a normal Desktop Effects checkbox named "Burning Windows". The real
// animation is the native remisa_burn backend, which reads this checkbox from
// kwinrc and therefore toggles without a KWin restart.
SceneEffect {
    id: effect
    visible: false
    delegate: Item {}
}
