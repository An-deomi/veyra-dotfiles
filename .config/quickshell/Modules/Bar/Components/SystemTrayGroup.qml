import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar
import qs.Modules.Bar.Widgets.SystemTray as STray

Rectangle {
    id: root

    property bool forceHide: false
    property bool compact: false
    property bool hasBackground: true
    property bool openMenuInline: false

    signal menuRequested(var trayItem)
    property int customHeight: compact ? Math.min(30, Math.round(22 * SettingsService.trayScale)) : SettingsService.barWidgetHeight
    readonly property real sideMargin: compact ? 6 : (hasBackground ? Constants.sizeXs : 0)
    readonly property real itemSpacing: compact ? 4 : (hasBackground ? Constants.sizeSm : Constants.size3Xs)
    readonly property bool shouldShow: !forceHide && trayRow.implicitWidth > 0
    readonly property real maxVisibleWidth: 240 + sideMargin * 2
    readonly property real targetWidth: Math.min(trayRow.implicitWidth + sideMargin * 2, maxVisibleWidth)

    implicitHeight: customHeight
    implicitWidth: shouldShow ? targetWidth : 0
    width: implicitWidth
    height: implicitHeight
    Layout.preferredHeight: customHeight
    Layout.alignment: Qt.AlignVCenter
    Layout.maximumWidth: 240 + sideMargin * 2
    Layout.preferredWidth: implicitWidth
    opacity: shouldShow ? 1 : 0
    visible: opacity > 0.001 && implicitWidth > 0.5
    clip: true
    color: hasBackground ? Theme.bgSecondary : "transparent"
    radius: DisplayProfileService.gameModeActive ? 0 : height / 2

    Flickable {
        id: trayFlick

        anchors.fill: parent
        anchors.leftMargin: root.sideMargin
        anchors.rightMargin: root.sideMargin
        contentWidth: trayRow.implicitWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        interactive: false
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                trayFlick.contentX = Math.max(0, Math.min(trayFlick.contentX - (wheel.angleDelta.y / 2), trayFlick.contentWidth - trayFlick.width));
            }
        }

        RowLayout {
            id: trayRow

            height: parent.height
            spacing: root.itemSpacing

            Repeater {
                model: SystemTray.items

                delegate: STray.TrayItem {
                    trayItem: modelData
                    itemIndex: index
                    customHeight: root.customHeight
                    iconSize: Math.min(Math.round(16 * SettingsService.trayScale), root.customHeight - 4)
                    onClicked: (mouse) => {
                        let isRight = (mouse.button === Qt.RightButton);
                        let isMenuClick = isRight || (mouse.button === Qt.LeftButton && modelData.onlyMenu);
                        if (isMenuClick) {
                            if (root.openMenuInline) {
                                root.menuRequested(modelData);
                            } else {
                                AppState.activeTrayItem = modelData;
                                AppState.toggleWidget("systemTray_" + index);
                            }
                        } else {
                            if (root.openMenuInline) {
                                root.menuRequested(null);
                            } else {
                                if (AppState.activeWidget.startsWith("systemTray_"))
                                    AppState.closeWidget(AppState.activeWidget);

                                for (let i = 0; i < AppState.activeWidgetsList.length; i++) {
                                    let w = AppState.activeWidgetsList[i];
                                    if (w && w.startsWith("systemTray_"))
                                        AppState.closeWidget(w);

                                }
                            }
                        }
                    }
                }

            }

        }

    }

    Behavior on Layout.preferredWidth {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
        }

    }

}
