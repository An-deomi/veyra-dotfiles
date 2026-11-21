import QtQuick
import QtQuick.Effects
import qs.Core
import qs.Core.Components
import qs.Core.Services

RectangularShadow {
    id: root

    property bool active: true
    property bool respectHyprland: true

    visible: active && (!respectHyprland || HyprlandService.hyprShadow) && !DisplayProfileService.gameModeActive && (SystemInfoService.effectivePowerProfile !== "power-saver")
    blur: HyprlandService.hyprShadowRange
    // hyprShadowRenderPower is a Hyprland 1-5 integer; RectangularShadow.spread is 0-1.
    // Scale down so render_power 5 maps to a gentle 0.5 lift instead of clamping above 1.
    spread: HyprlandService.hyprShadowRenderPower / 10
    color: Chrome.shadowColor
}
