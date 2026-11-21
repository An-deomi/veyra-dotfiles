import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar

BarButton {
    id: root

    property int iconSize: Constants.size2Xl + 4
    property bool enableIntervalAnim: true

    widgetId: "dashboard"
    implicitWidth: veyra.implicitWidth
    implicitHeight: veyra.implicitHeight
    height: implicitHeight

    AnimatedVeyra {
        id: veyra

        anchors.centerIn: parent
        iconSize: root.iconSize
        enableIntervalAnim: root.enableIntervalAnim

        Behavior on scale {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutQuad
            }

        }

    }

}
