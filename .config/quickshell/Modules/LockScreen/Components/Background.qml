import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import qs.Core
import qs.Core.Services
import qs.Core.Utils

Rectangle {
    id: bgRect

    property bool isDark: ColorUtils.isDark(Theme.bg)
    property real driftPhase: -1

    SequentialAnimation on driftPhase {
        running: bgRect.visible
        loops: Animation.Infinite

        NumberAnimation {
            from: -1
            to: 1
            duration: 7000
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            from: 1
            to: -1
            duration: 7000
            easing.type: Easing.InOutSine
        }

    }

    // The lock screen must remain fully opaque regardless of shell panel transparency.
    color: Theme.opaqueBg
    opacity: 1

    Image {
        id: wallpaperImg

        anchors.fill: parent
        sourceSize: Qt.size(480, 270)
        source: {
            let p = WallpaperManager.currentWallpaperPath;
            if (!p)
                return "";

            return p.startsWith("file://") ? p : ("file://" + p);
        }
        fillMode: {
            let mode = HyprlandService.wpResizeMode;
            if (mode === "fit")
                return Image.PreserveAspectFit;

            if (mode === "stretch")
                return Image.Stretch;

            return Image.PreserveAspectCrop;
        }
        horizontalAlignment: {
            let g = HyprlandService.wpCropGravity || "center";
            if (g.includes("left"))
                return Image.AlignLeft;

            if (g.includes("right"))
                return Image.AlignRight;

            return Image.AlignHCenter;
        }
        verticalAlignment: {
            let g = HyprlandService.wpCropGravity || "center";
            if (g.includes("top"))
                return Image.AlignTop;

            if (g.includes("bottom"))
                return Image.AlignBottom;

            return Image.AlignVCenter;
        }
        asynchronous: true
        cache: true
        layer.enabled: true

        layer.effect: MultiEffect {
            blurEnabled: SettingsService.lockScreenBackgroundBlur > 0
            blur: SettingsService.lockScreenBackgroundBlur
            blurMax: Constants.size5Xl
        }

    }

    Rectangle {
        anchors.fill: parent
        color: Theme.opaqueBg
        opacity: SettingsService.lockScreenBackgroundDim
    }

    Item {
        anchors.fill: parent
        opacity: 0.03

        Repeater {
            model: Math.ceil(parent.width / (Constants.size5Xl * 1.5))

            Rectangle {
                x: index * (Constants.size5Xl * 1.5)
                width: 1
                height: parent.height
                color: Theme.muted
            }

        }

        Repeater {
            model: Math.ceil(parent.height / (Constants.size5Xl * 1.5))

            Rectangle {
                y: index * (Constants.size5Xl * 1.5)
                width: parent.width
                height: 1
                color: Theme.muted
            }

        }

    }

    RadialGradient {
        anchors.fill: parent
        horizontalOffset: (parent.width / 3) + (bgRect.driftPhase * 48)
        verticalOffset: (-parent.height / 3.5) + (bgRect.driftPhase * 28)
        horizontalRadius: parent.width / 3
        verticalRadius: parent.height / 3

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.bgAccentComplementary
            }

            GradientStop {
                position: 1
                color: "transparent"
            }

        }

    }

    RadialGradient {
        anchors.fill: parent
        horizontalOffset: (-parent.width / 3) - (bgRect.driftPhase * 48)
        verticalOffset: (parent.height / 3.5) - (bgRect.driftPhase * 28)
        horizontalRadius: parent.width / 3
        verticalRadius: parent.height / 3

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.bgAccent
            }

            GradientStop {
                position: 1
                color: "transparent"
            }

        }

    }

}
