import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Rectangle {
    id: root

    property string label: ""
    property string iconName: "cpu"
    property string valueText: "–"
    property string detailText: ""
    property real fraction: 0
    property var history: []

    implicitWidth: 164
    implicitHeight: 116
    radius: Constants.sizeMd
    color: Theme.bgSecondary
    border.width: 1
    border.color: Theme.border

    onHistoryChanged: trend.requestPaint()

    function safeFraction() {
        const value = Number(root.fraction);
        return isFinite(value) ? Math.max(0, Math.min(1, value)) : 0;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            SvgIcon {
                icon: root.iconName
                iconSize: 14
                iconColor: Theme.accent
                Layout.alignment: Qt.AlignVCenter
            }

            ThemedText {
                Layout.fillWidth: true
                text: root.label
                customSize: 10
                color: Theme.muted
                font.bold: true
                elide: Text.ElideRight
            }
        }

        ThemedText {
            Layout.fillWidth: true
            text: root.valueText
            customSize: 17
            font.bold: true
            elide: Text.ElideRight
        }

        ThemedText {
            Layout.fillWidth: true
            text: root.detailText
            customSize: 9
            color: Theme.muted
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: Theme.bgTertiary
            clip: true

            Rectangle {
                width: parent.width * root.safeFraction()
                height: parent.height
                radius: parent.radius
                color: Theme.accent

                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
            }
        }

        Canvas {
            id: trend
            Layout.fillWidth: true
            Layout.preferredHeight: 13
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                const values = root.history || [];
                if (values.length < 2)
                    return;
                ctx.beginPath();
                ctx.lineWidth = 1.4;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.strokeStyle = Theme.accent.toString();
                for (let i = 0; i < values.length; i++) {
                    const x = 1 + (width - 2) * i / (values.length - 1);
                    const v = Math.max(0, Math.min(1, Number(values[i]) || 0));
                    const y = height - 1 - v * (height - 2);
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.stroke();
            }

            Component.onCompleted: requestPaint()
        }
    }
}
