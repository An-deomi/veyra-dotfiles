import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property bool enableShadow: true
    // Lets IslandBar draw one continuous surface while the island is idle.
    property real surfaceOpacity: SettingsService.islandBackdropBlur ? SettingsService.islandBackgroundOpacity : 1
    property real radius: height / 2
    readonly property bool useGradientBorder: SettingsService.islandBorderEnabled && SettingsService.islandBorderColorMode === "gradient"
    property real borderAngle: 0.785398
    default property alias content: contentSlot.data

    NumberAnimation on borderAngle {
        from: 0
        to: Math.PI * 2
        duration: Math.max(1500, SettingsService.hyprAnimBorderSpeed * 90)
        loops: Animation.Infinite
        running: root.useGradientBorder
            && SettingsService.hyprAnimBorderSpin
            && HyprlandService.enableAnimations
            && !DisplayProfileService.gameModeActive
            && (SystemInfoService.effectivePowerProfile !== "power-saver")
    }

    ThemedShadow {
        anchors.fill: parent
        radius: root.radius
        respectHyprland: false
        active: root.enableShadow && SettingsService.islandShadowEnabled && !DisplayProfileService.gameModeActive && (SystemInfoService.effectivePowerProfile !== "power-saver")
        opacity: SettingsService.islandShadowStrength / 100
        visible: active && opacity > 0.001
    }

    Rectangle {
        id: shape

        anchors.fill: parent
        anchors.margins: root.useGradientBorder ? 1 : 0
        radius: Math.max(0, root.radius - anchors.margins)
        color: Theme.opaqueBg
        opacity: root.surfaceOpacity
        border.width: (SettingsService.islandBorderEnabled && !root.useGradientBorder) ? SettingsService.islandBorderWidth : 0
        border.color: SettingsService.islandBorderColorMode === "subtle" ? Theme.border : Theme.accent
        antialiasing: true
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4

        Behavior on color {
            ColorAnimation {
                duration: Constants.animNormal
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Constants.animNormal
            }
        }

        Behavior on border.width {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }
        }

    }

    Rectangle {
        id: gradientBorderRect

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real dx: Math.cos(root.borderAngle) * cx
        readonly property real dy: Math.sin(root.borderAngle) * cy

        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: root.useGradientBorder ? SettingsService.islandBorderWidth : 0
        border.color: Theme.accent
        antialiasing: true
        visible: root.useGradientBorder
        layer.enabled: visible
        layer.smooth: true
        layer.samples: 4
        layer.effect: LinearGradient {
            start: Qt.point(gradientBorderRect.cx - gradientBorderRect.dx, gradientBorderRect.cy - gradientBorderRect.dy)
            end: Qt.point(gradientBorderRect.cx + gradientBorderRect.dx, gradientBorderRect.cy + gradientBorderRect.dy)
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.accent
                }

                GradientStop {
                    position: 1.0
                    color: Theme.accentComplementary
                }
            }
        }
    }

    Item {
        id: contentSlot

        anchors.fill: parent
    }

}
