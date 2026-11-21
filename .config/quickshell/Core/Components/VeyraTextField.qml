import QtQuick
import QtQuick.Controls
import qs.Core
import qs.Core.Services

// Shared Veyra input styling. Callers can still override background, sizing,
// padding, font, and echoMode when a specialized layout needs it.
TextField {
    id: control

    property real cornerRadius: Constants.sizeSm

    font.family: Constants.fontFamily
    font.pixelSize: Math.round(Constants.sizeMd * SettingsService.fontScale)
    color: Theme.fg
    placeholderTextColor: Theme.muted
    selectionColor: Theme.accent
    selectedTextColor: Theme.isDark ? Theme.opaqueBg : Theme.fg
    selectByMouse: true

    leftPadding: Constants.sizeMd
    rightPadding: Constants.sizeMd
    topPadding: Constants.size2Xs
    bottomPadding: Constants.size2Xs
    implicitHeight: Constants.size4Xl + 2

    background: Rectangle {
        radius: control.cornerRadius
        color: !control.enabled
            ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.34)
            : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b,
                control.activeFocus ? (Theme.isDark ? 0.84 : 0.92) : (Theme.isDark ? 0.68 : 0.82))
        border.width: control.activeFocus ? 1.6 : 1
        border.color: control.activeFocus ? Theme.accent : (control.hovered ? Theme.muted : Theme.border)

        Behavior on border.color {
            ColorAnimation { duration: Constants.animFast }
        }

        Behavior on color {
            ColorAnimation { duration: Constants.animFast }
        }
    }
}
