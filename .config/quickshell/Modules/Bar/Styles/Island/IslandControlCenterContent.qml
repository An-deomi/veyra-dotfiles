import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Widgets.SystemTray as TrayModule
import qs.Modules.ControlCenter as ControlCenterModule

ColumnLayout {
    id: root

    property var widget: null
    property var notificationService: null
    property var activeTrayItem: null
    spacing: Constants.sizeSm
    implicitWidth: Math.max(420, trayHeader.implicitWidth, activeTrayItem ? trayMenu.implicitWidth : controlCenter.implicitWidth)
    implicitHeight: (trayRepeater.count > 0 ? trayHeader.implicitHeight + spacing : 0) + (activeTrayItem ? (menuHeader.implicitHeight + spacing + trayMenu.implicitHeight) : controlCenter.implicitHeight)

    RowLayout {
        id: trayHeader
        visible: trayRepeater.count > 0
        Layout.fillWidth: true
        spacing: Constants.sizeSm

        Item { Layout.fillWidth: true; implicitWidth: 8; implicitHeight: 1 }

        Item {
            id: trayHost
            readonly property int iconHeight: Math.min(30, Math.round(22 * SettingsService.trayScale))
            readonly property int iconSpacing: Constants.sizeXs
            implicitWidth: trayRepeater.count > 0 ? trayRepeater.count * iconHeight + (trayRepeater.count - 1) * iconSpacing : 0
            implicitHeight: iconHeight
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.alignment: Qt.AlignVCenter

            Row {
                anchors.fill: parent
                spacing: trayHost.iconSpacing
                visible: trayRepeater.count > 0
                Repeater {
                    id: trayRepeater
                    model: SystemTray.items
                    delegate: TrayModule.TrayItem {
                        trayItem: modelData
                        itemIndex: index
                        customHeight: trayHost.iconHeight
                        iconSize: Math.min(Math.round(16 * SettingsService.trayScale), trayHost.iconHeight - 4)
                        onClicked: (mouse) => {
                            const openMenu = mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && modelData.onlyMenu)
                            if (openMenu)
                                root.activeTrayItem = modelData
                            else
                                root.activeTrayItem = null
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: menuHeader
        visible: root.activeTrayItem !== null
        Layout.fillWidth: true
        spacing: Constants.sizeSm
        Item {
            width: Constants.sizeXl
            height: Constants.sizeXl
            SvgIcon {
                anchors.centerIn: parent
                icon: "arrow-left"
                iconSize: Constants.sizeLg
                iconColor: backHover.hovered ? Theme.accent : Theme.muted
                flat: true
                HoverHandler { id: backHover }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTrayItem = null
            }
        }
        ThemedText {
            text: root.activeTrayItem && root.activeTrayItem.title ? root.activeTrayItem.title.toString() : "System tray menu"
            customSize: Constants.sizeMd
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    TrayModule.TrayMenu {
        id: trayMenu
        visible: root.activeTrayItem !== null
        Layout.fillWidth: true
        implicitWidth: 340
        maxContentHeight: 380
        menuHandle: root.activeTrayItem ? root.activeTrayItem.menu : null
        title: (root.activeTrayItem && root.activeTrayItem.title && root.activeTrayItem.title.toString().trim() !== "") ? root.activeTrayItem.title.toString().trim() : "Menu"
        onMenuHandleChanged: resetToRoot()
        onCloseRequested: root.activeTrayItem = null
        onBackRequested: root.activeTrayItem = null
    }

    ControlCenterModule.ControlCenterContent {
        id: controlCenter
        widget: root.widget
        notificationService: root.notificationService
        visible: root.activeTrayItem === null
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}
