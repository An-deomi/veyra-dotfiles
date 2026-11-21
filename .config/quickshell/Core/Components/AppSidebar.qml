import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property int sidebarWidth: 250
    property alias contentSpacing: contentCol.spacing
    default property alias content: contentCol.data

    Layout.preferredWidth: root.sidebarWidth
    Layout.minimumWidth: root.sidebarWidth
    Layout.maximumWidth: root.sidebarWidth
    Layout.fillHeight: true
    color: Theme.bgSecondary

    Divider {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        vertical: true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Constants.sizeLg
            Layout.rightMargin: Constants.sizeLg
            Layout.topMargin: Constants.sizeXl
            Layout.bottomMargin: Constants.sizeLg
            spacing: Constants.sizeSm
            visible: root.title !== "" || root.subtitle !== ""

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                Rectangle {
                    Layout.preferredWidth: 5
                    Layout.preferredHeight: 28
                    radius: 3
                    color: Theme.accent
                }

                ThemedText {
                    Layout.fillWidth: true
                    visible: root.title !== ""
                    text: root.title
                    customSize: Constants.sizeXl
                    font.weight: Font.Bold
                    font.letterSpacing: 1.0
                    color: Theme.fg
                    elide: Text.ElideRight
                }
            }

            ThemedText {
                visible: root.subtitle !== ""
                text: root.subtitle
                customSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
                color: Theme.muted
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Constants.sizeLg
            Layout.rightMargin: Constants.sizeLg
            Layout.preferredHeight: 1
            color: Theme.border
        }

        Flickable {
            id: navFlickable

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: contentCol.implicitHeight + Constants.sizeLg

            ColumnLayout {
                id: contentCol

                width: navFlickable.width
                spacing: Constants.size2Xs

                Item {
                    Layout.preferredHeight: Constants.sizeSm
                }
            }

            ScrollBar.vertical: ScrollBar {
                parent: navFlickable
                anchors.right: navFlickable.right
                anchors.top: navFlickable.top
                anchors.bottom: navFlickable.bottom
                policy: ScrollBar.AsNeeded
                width: Constants.size2Xs
            }
        }
    }
}
