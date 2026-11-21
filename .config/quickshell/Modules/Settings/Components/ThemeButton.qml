import QtQuick
import QtQuick.Controls
import qs.Core

Button {
    id: control

    implicitHeight: 36
    padding: Constants.sizeSm
    font.pixelSize: 12

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? Theme.fg : Theme.muted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 78
        implicitHeight: 36
        radius: Constants.sizeXs
        color: !control.enabled ? Theme.bg
             : control.down ? Theme.bgAccent
             : control.hovered ? Theme.bgTertiary
             : Theme.bgSecondary
        border.width: 1
        border.color: control.enabled && (control.down || control.hovered)
                    ? Theme.accent : Theme.border
    }
}
