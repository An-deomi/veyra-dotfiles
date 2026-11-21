import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components

Item {
    id: delegateRoot

    property var modelData
    property bool isCurrent: false
    property bool isExpanded: false
    property bool isPinned: false
    property int currentActionIndex: -1
    readonly property bool hasActions: modelData.actions && modelData.actions.length > 0
    readonly property int actionCount: modelData.actions ? modelData.actions.length : 0

    signal toggleExpanded()
    signal launchRequested(string exec, bool inTerminal, string appId)
    signal pinToggleRequested(string appId)

    onIsExpandedChanged: {
        if (!isExpanded)
            currentActionIndex = -1;

    }
    width: ListView.view ? ListView.view.width : 400
    height: 44 + (isExpanded ? actionsColumn.implicitHeight + Constants.sizeXs : 0)
    z: 2
    clip: true

    Item {
        id: mainContent

        width: parent.width
        height: 44

        Rectangle {
            anchors.fill: parent
            radius: Constants.sizeLg
            color: Theme.bgSecondary
            visible: hoverHandler.hovered && !isCurrent
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Constants.sizeLg
            anchors.rightMargin: Constants.size4Xl + Constants.sizeXl
            spacing: Constants.sizeLg

            Item {
                Layout.preferredWidth: Constants.size2Xl
                Layout.preferredHeight: Constants.size2Xl

                Image {
                    id: appIcon

                    anchors.fill: parent
                    sourceSize: Qt.size(64, 64)
                    source: {
                        if (!modelData.icon)
                            return "";

                        let path = modelData.icon;
                        let home = Quickshell.env("HOME");
                        if (path.startsWith("$HOME"))
                            path = home + path.substring(5);
                        else if (path.startsWith("~"))
                            path = home + path.substring(1);
                        if (path.startsWith("/") || path.startsWith("file://"))
                            return path.startsWith("file://") ? path : "file://" + path;

                        return Quickshell.iconPath(path, true);
                    }
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                }

                SvgIcon {
                    anchors.fill: parent
                    icon: "rocket"
                    iconSize: Constants.size2Xl
                    flat: true
                    iconColor: isCurrent ? Theme.accent : Theme.muted
                    visible: !appIcon.visible
                }

            }

            ThemedText {
                text: modelData.name
                color: isCurrent ? Theme.accent : Theme.fg
                font.bold: isCurrent
                customSize: Constants.sizeMd
                Layout.fillWidth: true
                scale: isCurrent ? 1.02 : 1
                transformOrigin: Item.Left

                Behavior on color {
                    ColorAnimation {
                        duration: Constants.animNormal
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutQuint
                    }

                }

            }

        }

        HoverHandler {
            id: hoverHandler
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    appContextMenu.popup(mainContent, mouse.x, mouse.y);
                } else {
                    delegateRoot.launchRequested(delegateRoot.modelData.exec, delegateRoot.modelData.terminal, delegateRoot.modelData.id);
                }
            }
        }

        MouseArea {
            id: pinMouseArea
            width: 28
            height: 28
            anchors.right: parent.right
            anchors.rightMargin: delegateRoot.hasActions ? Constants.size4Xl : Constants.sizeXs
            anchors.verticalCenter: mainContent.verticalCenter
            z: 5
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: delegateRoot.pinToggleRequested(modelData.id)

            Text {
                anchors.centerIn: parent
                text: delegateRoot.isPinned ? "★" : "☆"
                color: delegateRoot.isPinned ? Theme.accent : (pinMouseArea.containsMouse ? Theme.fg : Theme.muted)
                font.pixelSize: 19
            }
        }

        SvgIconButton {
            icon: "chevron-right"
            iconSize: Constants.sizeMd
            visible: delegateRoot.hasActions
            iconColor: delegateRoot.isExpanded ? Theme.fg : Theme.muted
            anchors.right: parent.right
            anchors.rightMargin: Constants.sizeXs
            anchors.verticalCenter: mainContent.verticalCenter
            rotation: delegateRoot.isExpanded ? 90 : 0
            flat: true
            onClicked: {
                delegateRoot.toggleExpanded();
            }

            Behavior on rotation {
                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutQuint
                }

            }

        }

    }

    Item {
        id: connectorLines

        y: 44 + Constants.sizeXs / 2
        width: parent.width
        height: actionsColumn.implicitHeight
        visible: delegateRoot.isExpanded

        Rectangle {
            x: Constants.sizeLg + 11
            y: -Constants.sizeXs / 2
            width: Constants.size3Xs
            height: parent.height - 12
            color: Theme.muted
            radius: width / 2
        }

        Repeater {
            model: modelData.actions || []

            Rectangle {
                x: Constants.sizeLg + 11
                y: index * (34 + actionsColumn.spacing) + 16
                width: Constants.sizeLg
                height: Constants.size3Xs
                color: Theme.muted
                radius: height / 2
            }

        }

    }

    ColumnLayout {
        id: actionsColumn

        y: 44 + Constants.sizeXs / 2
        width: parent.width
        spacing: Constants.size2Xs
        visible: delegateRoot.isExpanded

        Repeater {
            model: modelData.actions || []

            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                Layout.leftMargin: Constants.size4Xl
                color: "transparent"
                radius: Constants.sizeLg

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Constants.sizeMd
                    anchors.rightMargin: Constants.sizeLg
                    spacing: Constants.sizeXs

                    Item {
                        Layout.preferredWidth: Constants.sizeXs
                        Layout.preferredHeight: Constants.sizeXs
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: width / 2
                            color: ((delegateRoot.isExpanded && delegateRoot.currentActionIndex === index) || actionMouseArea.containsMouse) ? Theme.accent : Theme.muted
                            scale: ((delegateRoot.isExpanded && delegateRoot.currentActionIndex === index) || actionMouseArea.containsMouse) ? 1.5 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: Constants.animFast
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Constants.animFast
                                    easing.type: Easing.OutBack
                                }

                            }

                        }

                    }

                    ThemedText {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: ((delegateRoot.isExpanded && delegateRoot.currentActionIndex === index) || actionMouseArea.containsMouse) ? Theme.accent : Theme.fg
                        customSize: Constants.sizeMd
                        Layout.alignment: Qt.AlignVCenter

                        Behavior on color {
                            ColorAnimation {
                                duration: Constants.animFast
                            }

                        }

                    }

                }

                MouseArea {
                    id: actionMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: delegateRoot.launchRequested(modelData.exec, false, delegateRoot.modelData.id)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Constants.animFast
                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Constants.animFast
                    }

                }

            }

        }

    }

    Menu {
        id: appContextMenu
        width: 232
        padding: Constants.sizeXs
        modal: false
        focus: true

        delegate: MenuItem {
            id: contextMenuItem
            implicitWidth: 220
            implicitHeight: 34
            hoverEnabled: true

            contentItem: Text {
                anchors.fill: parent
                anchors.leftMargin: Constants.sizeMd
                anchors.rightMargin: Constants.sizeMd
                text: contextMenuItem.text
                color: !contextMenuItem.enabled ? Theme.muted
                     : (contextMenuItem.hovered || contextMenuItem.highlighted
                        ? Theme.accent : Theme.fg)
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: Constants.sizeSm
                color: contextMenuItem.down ? Theme.bgAccent
                     : (contextMenuItem.hovered || contextMenuItem.highlighted
                        ? Theme.bgTertiary : Theme.bgSecondary)
                border.width: contextMenuItem.hovered || contextMenuItem.highlighted ? 1 : 0
                border.color: Theme.accent
            }
        }

        background: Rectangle {
            color: Theme.bg
            radius: Constants.sizeLg
            border.width: 1
            border.color: Theme.border
        }

        MenuItem {
            id: launchMenuItem
            hoverEnabled: true
            text: "Launch"

            contentItem: Text {
                anchors.fill: parent
                anchors.leftMargin: Constants.sizeMd
                anchors.rightMargin: Constants.sizeMd
                text: launchMenuItem.text
                font: launchMenuItem.font
                color: !launchMenuItem.enabled ? Theme.muted
                     : (launchMenuItem.hovered || launchMenuItem.highlighted
                        ? Theme.accent : Theme.fg)
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: Constants.sizeSm
                color: launchMenuItem.down ? Theme.bgAccent
                     : (launchMenuItem.hovered || launchMenuItem.highlighted
                        ? Theme.bgTertiary : Theme.bgSecondary)
                border.width: launchMenuItem.hovered || launchMenuItem.highlighted ? 1 : 0
                border.color: Theme.accent
            }

            onTriggered: delegateRoot.launchRequested(delegateRoot.modelData.exec, delegateRoot.modelData.terminal, delegateRoot.modelData.id)
        }

        MenuItem {
            id: terminalMenuItem
            hoverEnabled: true
            text: "Launch in Terminal"

            contentItem: Text {
                anchors.fill: parent
                anchors.leftMargin: Constants.sizeMd
                anchors.rightMargin: Constants.sizeMd
                text: terminalMenuItem.text
                font: terminalMenuItem.font
                color: !terminalMenuItem.enabled ? Theme.muted
                     : (terminalMenuItem.hovered || terminalMenuItem.highlighted
                        ? Theme.accent : Theme.fg)
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: Constants.sizeSm
                color: terminalMenuItem.down ? Theme.bgAccent
                     : (terminalMenuItem.hovered || terminalMenuItem.highlighted
                        ? Theme.bgTertiary : Theme.bgSecondary)
                border.width: terminalMenuItem.hovered || terminalMenuItem.highlighted ? 1 : 0
                border.color: Theme.accent
            }

            onTriggered: delegateRoot.launchRequested(delegateRoot.modelData.exec, true, delegateRoot.modelData.id)
        }

        MenuSeparator {
            contentItem: Rectangle {
                implicitHeight: 1
                color: Theme.border
            }
        }

        MenuItem {
            id: pinMenuItem
            hoverEnabled: true
            text: delegateRoot.isPinned ? "Unpin from Favorites" : "Pin to Favorites"

            contentItem: Text {
                anchors.fill: parent
                anchors.leftMargin: Constants.sizeMd
                anchors.rightMargin: Constants.sizeMd
                text: pinMenuItem.text
                font: pinMenuItem.font
                color: !pinMenuItem.enabled ? Theme.muted
                     : (pinMenuItem.hovered || pinMenuItem.highlighted
                        ? Theme.accent : Theme.fg)
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: Constants.sizeSm
                color: pinMenuItem.down ? Theme.bgAccent
                     : (pinMenuItem.hovered || pinMenuItem.highlighted
                        ? Theme.bgTertiary : Theme.bgSecondary)
                border.width: pinMenuItem.hovered || pinMenuItem.highlighted ? 1 : 0
                border.color: Theme.accent
            }

            onTriggered: delegateRoot.pinToggleRequested(delegateRoot.modelData.id)
        }

        MenuSeparator {
            visible: delegateRoot.hasActions
            contentItem: Rectangle {
                implicitHeight: 1
                color: Theme.border
            }
        }

        Repeater {
            model: delegateRoot.modelData.actions || []

            delegate: MenuItem {
                text: modelData.name
                onTriggered: delegateRoot.launchRequested(modelData.exec, false, delegateRoot.modelData.id)
            }
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutQuint
        }

    }

}
