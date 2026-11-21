import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Widgets.SystemTray as TrayModule
import qs.Modules.Dashboard as DashboardModule

ColumnLayout {
    id: root

    property var widget: null
    property var activeTrayItem: null
    spacing: Constants.sizeMd
    implicitWidth: Math.max(headerRow.implicitWidth, activeTrayItem ? trayMenu.implicitWidth : dashboardContent.implicitWidth)
    implicitHeight: headerRow.implicitHeight + spacing + (activeTrayItem ? (trayMenuHeader.implicitHeight + spacing + trayMenu.implicitHeight) : dashboardContent.implicitHeight)

    RowLayout {
        id: headerRow

        Layout.fillWidth: true
        spacing: Constants.sizeMd

        Rectangle {
            id: clockCapsule

            color: Theme.bgSecondary
            radius: height / 2
            implicitWidth: dashboardClock.implicitWidth + Constants.sizeLg * 2
            implicitHeight: Constants.size3Xl
            Layout.alignment: Qt.AlignVCenter

            IslandClock {
                id: dashboardClock

                anchors.centerIn: parent
                clickable: true
                clickWidget: "clock"
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }

        Item {
            Layout.fillWidth: true
            implicitWidth: 8
            implicitHeight: 1
        }

        Item {
            id: dashboardTrayHost

            // Compute size on the host Item; Row's implicit size is positioner-managed.
            implicitWidth: trayRepeater.count > 0
                ? (trayRepeater.count * dashboardTray.iconHeight) + ((trayRepeater.count - 1) * dashboardTray.iconSpacing)
                : 0
            implicitHeight: dashboardTray.iconHeight
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.alignment: Qt.AlignVCenter

            Row {
                id: dashboardTray

                readonly property int iconHeight: Math.min(30, Math.round(22 * SettingsService.trayScale))
                readonly property int iconSpacing: Constants.sizeXs
                // Positioners calculate implicit dimensions themselves; size the Row from its host.
                width: parent.width
                height: parent.height
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: iconSpacing
                visible: trayRepeater.count > 0

                Repeater {
                    id: trayRepeater
                    model: SystemTray.items

                    delegate: TrayModule.TrayItem {
                        trayItem: modelData
                        itemIndex: index
                        customHeight: dashboardTray.iconHeight
                        iconSize: Math.min(Math.round(16 * SettingsService.trayScale), dashboardTray.iconHeight - 4)

                        onClicked: (mouse) => {
                            let isRight = mouse.button === Qt.RightButton;
                            let isMenuClick = isRight || (mouse.button === Qt.LeftButton && modelData.onlyMenu);
                            if (isMenuClick)
                                root.activeTrayItem = modelData;
                            else
                                root.activeTrayItem = null;
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: trayMenuHeader

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
            text: "Back to dashboard"
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
        Layout.fillHeight: false
        implicitWidth: 340
        maxContentHeight: 380
        menuHandle: root.activeTrayItem ? root.activeTrayItem.menu : null
        title: (root.activeTrayItem && root.activeTrayItem.title && root.activeTrayItem.title.toString().trim() !== "") ? root.activeTrayItem.title.toString().trim() : "Menu"
        onMenuHandleChanged: resetToRoot()
        onCloseRequested: root.activeTrayItem = null
    }

    DashboardModule.DashboardContent {
        id: dashboardContent

        widget: root.widget
        visible: root.activeTrayItem === null
        Layout.fillWidth: true
        Layout.fillHeight: false
    }
}
