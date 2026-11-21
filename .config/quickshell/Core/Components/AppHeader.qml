import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

ColumnLayout {
    id: root

    property string title: ""
    property string category: ""
    property string subtitle: ""
    property bool showDivider: false
    default property alias actions: rightSlot.data

    Layout.fillWidth: true
    spacing: 0

    Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(headerRow.implicitHeight + Constants.sizeXl * 2, 82)

        RowLayout {
            id: headerRow

            anchors.fill: parent
            anchors.leftMargin: Constants.sizeXl
            anchors.rightMargin: Constants.sizeXl
            anchors.topMargin: Constants.sizeMd
            anchors.bottomMargin: Constants.sizeMd
            spacing: Constants.sizeLg

            Rectangle {
                Layout.preferredWidth: 4
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignVCenter
                radius: 2
                color: Theme.accent
            }

            ColumnLayout {
                spacing: Constants.size2Xs
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Math.max(120, parent.width - (rightSlot.width > 0 ? rightSlot.width + Constants.sizeXl : 0))

                RowLayout {
                    spacing: Constants.sizeSm

                    ThemedText {
                        text: root.title
                        customSize: Constants.sizeXl + 2
                        font.weight: Font.Bold
                        color: Theme.fg
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: root.category !== ""
                        implicitHeight: 22
                        implicitWidth: categoryText.implicitWidth + Constants.sizeMd
                        radius: 11
                        color: Theme.bgAccent
                        border.width: 1
                        border.color: Theme.border
                        Layout.alignment: Qt.AlignVCenter

                        ThemedText {
                            id: categoryText
                            anchors.centerIn: parent
                            text: root.category
                            customSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: Theme.accent
                        }
                    }
                }

                ThemedText {
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    customSize: Constants.sizeXs + 2
                    color: Theme.muted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                id: rightSlot
                Layout.alignment: Qt.AlignVCenter
                spacing: Constants.sizeSm
            }
        }
    }

    Divider {
        visible: root.showDivider
    }
}
