import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

// "Label ........ value" with an optional progress bar underneath.
ColumnLayout {
    id: root

    property string label: ""
    property string valueText: ""
    property real fraction: 0
    property var history: []
    property bool showBar: true

    onHistoryChanged: {
        if (historyGraph)
            historyGraph.requestPaint();
    }

    Layout.fillWidth: true
    spacing: 4

    RowLayout {
        Layout.fillWidth: true

        ThemedText {
            Layout.fillWidth: true
            text: root.label
            color: Theme.muted
            elide: Text.ElideRight
        }

        ThemedText {
            text: root.valueText
            font.bold: true
        }

    }

    RowLayout {
        visible: root.showBar
        Layout.fillWidth: true
        Layout.preferredHeight: 14
        spacing: Constants.sizeSm

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            Layout.alignment: Qt.AlignVCenter
            radius: 3
            color: Theme.bgSecondary

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.fraction))
                height: parent.height
                radius: parent.radius
                color: Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Canvas {
            id: historyGraph
            Layout.preferredWidth: 58
            Layout.preferredHeight: 14
            Layout.alignment: Qt.AlignVCenter
            antialiasing: true

            onPaint: {
                let values = root.history || [];
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (values.length < 2)
                    return;

                ctx.beginPath();
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = Theme.accent.toString();
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                for (let i = 0; i < values.length; i++) {
                    let x = 1 + (width - 2) * i / (values.length - 1);
                    let v = Math.max(0, Math.min(1, Number(values[i]) || 0));
                    let y = height - 1 - v * (height - 2);
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.stroke();
            }

            Component.onCompleted: requestPaint()

            Connections {
                target: root
                function onHistoryChanged() {
                    historyGraph.requestPaint();
                }
            }
        }
    }

}
