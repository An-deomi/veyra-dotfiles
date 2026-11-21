import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Item {
    id: root

    property var uiElements: []
    property string desc: ""
    property bool custom: false
    property var bindData: ({})

    signal editRequested(var data)
    signal deleteRequested(var data)

    Layout.fillWidth: true
    implicitHeight: Math.max(contentRow.implicitHeight, 28)

    RowLayout {
        id: contentRow

        anchors.fill: parent
        spacing: Constants.sizeMd

        ThemedText {
            text: root.desc
            customSize: Constants.sizeSm
            color: Theme.fg
            Layout.fillWidth: true
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
        }

        ThemedText {
            visible: root.custom
            text: "CUSTOM"
            customSize: 9
            color: Theme.accent
            font.weight: Font.Bold
            font.letterSpacing: 0.5
        }

        Row {
            spacing: 5
            Layout.alignment: Qt.AlignVCenter

            Repeater {
                model: root.uiElements

                delegate: Item {
                    required property var modelData

                    width: modelData.isKey ? keyCapBase.width : sepText.implicitWidth
                    height: 26

                    Rectangle {
                        id: keyCapBase

                        visible: modelData.isKey
                        width: Math.max(capText.implicitWidth + Constants.sizeMd, Constants.size2Xl + 2)
                        height: Constants.size2Xl + 2
                        radius: Constants.size2Xs + 2
                        color: Theme.bgTertiary
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: keyCapSurface

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: parent.height - 2
                            radius: Constants.size2Xs + 2
                            color: Theme.bgTertiary
                            border.color: Theme.border
                            border.width: 1

                            ThemedText {
                                id: capText

                                anchors.centerIn: parent
                                text: modelData.isKey ? modelData.text : ""
                                color: Theme.fg
                                customSize: Constants.sizeSm
                                font.bold: true
                            }

                        }

                    }

                    ThemedText {
                        id: sepText

                        visible: !modelData.isKey
                        text: !modelData.isKey ? modelData.text : ""
                        color: Theme.muted
                        customSize: Constants.sizeSm
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

            }

        }

        RowLayout {
            visible: root.custom
            spacing: Constants.size2Xs
            Layout.alignment: Qt.AlignVCenter

            SvgIconButton {
                icon: "tune"
                iconSize: Constants.sizeSm
                padding: Constants.size2Xs
                flat: true
                iconColor: Theme.muted
                hoverColor: Theme.accent
                onClicked: root.editRequested(root.bindData)
            }

            SvgIconButton {
                icon: "trash"
                iconSize: Constants.sizeSm
                padding: Constants.size2Xs
                flat: true
                iconColor: Theme.muted
                hoverColor: Theme.accentComplementary
                onClicked: root.deleteRequested(root.bindData)
            }
        }

    }

}
