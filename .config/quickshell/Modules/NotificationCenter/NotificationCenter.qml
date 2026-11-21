import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.NotificationCenter.Components

Item {
    id: root

    property var notificationService
    property var currentTime: SystemInfoService.currentTime
    property bool controlCenterOpen: false
    property bool isClearingAll: false
    property string searchQuery: ""
    property string filterMode: "all"
    property var filteredEntries: []

    function rebuildFilteredEntries() {
        if (!notificationService || !notificationService.historyList) {
            filteredEntries = [];
            return;
        }
        const query = searchQuery.trim().toLowerCase();
        const output = [];
        const model = notificationService.historyList;
        for (let i = 0; i < model.count; i++) {
            const entry = model.get(i);
            const data = entry ? entry.notifData : null;
            if (!data)
                continue;
            const app = String(data.appName || "").trim();
            const isSystem = app === "" || app.toLowerCase() === "system" || app.toLowerCase() === "veyra";
            if (filterMode === "apps" && isSystem)
                continue;
            if (filterMode === "system" && !isSystem)
                continue;
            const haystack = [app, data.summary || "", data.body || ""].join(" ").toLowerCase();
            if (query !== "" && !haystack.includes(query))
                continue;
            output.push({ id: entry.id, notifData: data });
        }
        filteredEntries = output;
    }

    function setFilter(mode) {
        filterMode = mode;
        rebuildFilteredEntries();
    }

    function startClearAllAnimation() {
        if (isClearingAll || !notificationService || !notificationService.historyList || notificationService.historyList.count === 0)
            return ;

        isClearingAll = true;
    }

    onVisibleChanged: {
        if (!visible)
            isClearingAll = false;
        else
            rebuildFilteredEntries();
    }

    Component.onCompleted: rebuildFilteredEntries()

    Connections {
        target: root.notificationService ? root.notificationService.historyList : null
        function onCountChanged() { root.rebuildFilteredEntries(); }
    }

    // Notification objects can update in place (summary/body changes) without
    // changing the ListModel count. Refresh only while this panel is visible so
    // search and category filters stay accurate without a permanent poll.
    Timer {
        interval: 900
        repeat: true
        running: root.visible
        onTriggered: root.rebuildFilteredEntries()
    }

    implicitWidth: 400
    implicitHeight: 450

    ColumnLayout {
        anchors.fill: parent
        spacing: Constants.sizeLg

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Constants.size3Xs

                ThemedText {
                    text: "Notifications"
                    customSize: Constants.sizeLg
                    font.bold: true
                    color: Theme.fg
                }

                ThemedText {
                    text: (notificationService && notificationService.historyList && notificationService.historyList.count > 0 && !root.isClearingAll) ? (notificationService.historyList.count + (notificationService.historyList.count === 1 ? " saved notification" : " saved notifications")) : "All caught up"
                    customSize: Constants.sizeXs + 2
                    color: Theme.muted
                }

            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Constants.sizeXs
                Layout.alignment: Qt.AlignVCenter

                SvgIconButton {
                    isActive: root.notificationService && root.notificationService.dndEnabled
                    icon: isActive ? "bell-off" : "bell"
                    iconColor: isActive ? Theme.fg : Theme.accent
                    iconSize: Constants.sizeSm
                    textIcon: DisplayProfileService.gameModeActive ? "Game Mode" : (root.notificationService && root.notificationService.quietHoursActive ? "Quiet" : (root.notificationService && root.notificationService.mediaDndActive ? "Media" : (SettingsService.notificationsDndEnabled ? "DND on" : "Mute")))
                    textIconSize: Constants.sizeSm
                    useCustomWidth: true
                    disabled: DisplayProfileService.gameModeActive || (root.notificationService && (root.notificationService.quietHoursActive || root.notificationService.mediaDndActive))
                    onClicked: {
                        SettingsService.notificationsDndEnabled = !SettingsService.notificationsDndEnabled;
                    }
                }

                SvgIconButton {
                    icon: "trash"
                    iconSize: Constants.sizeSm
                    iconColor: Theme.accent
                    textIcon: "Clear All"
                    textIconSize: Constants.sizeSm
                    onClicked: {
                        if (notificationService && notificationService.historyList && notificationService.historyList.count > 0)
                            root.startClearAllAnimation();

                    }
                    useCustomWidth: true
                    disabled: !notificationService || !notificationService.historyList || notificationService.historyList.count === 0 || root.isClearingAll
                }

            }

        }

        ThemedSearchBar {
            Layout.fillWidth: true
            preferredHeight: 34
            customSize: Constants.sizeXs + 1
            autoFocus: false
            placeholderText: "Search notifications…"
            onSearchRequested: (value) => {
                root.searchQuery = value;
                root.rebuildFilteredEntries();
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.size2Xs
            Repeater {
                model: [
                    { id: "all", label: "All" },
                    { id: "apps", label: "Apps" },
                    { id: "system", label: "System" }
                ]
                delegate: Button {
                    id: filterButton
                    required property var modelData
                    checkable: true
                    checked: root.filterMode === modelData.id
                    text: modelData.label
                    implicitHeight: 28
                    Layout.fillWidth: true
                    onClicked: root.setFilter(modelData.id)
                    contentItem: Text {
                        text: filterButton.text
                        color: filterButton.checked ? Theme.fg : Theme.muted
                        font.pixelSize: 10
                        font.weight: filterButton.checked ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 9
                        color: filterButton.checked ? Theme.bgAccent : Theme.bgSecondary
                        border.width: 1
                        border.color: filterButton.checked ? Theme.accent : Theme.border
                    }
                }
            }
            Item { Layout.fillWidth: true }
            ThemedText {
                text: root.filteredEntries.length + " shown"
                customSize: 9
                color: Theme.muted
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Constants.sizeXs

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    id: emptyState

                    anchors.centerIn: parent
                    spacing: Constants.sizeSm
                    visible: opacity > 0
                    opacity: (root.filteredEntries.length === 0 && !root.isClearingAll) ? 1 : 0

                    SvgIcon {
                        icon: "bell"
                        iconSize: Constants.size5Xl
                        iconColor: Theme.muted
                        Layout.alignment: Qt.AlignHCenter
                        flat: true
                    }

                    ThemedText {
                        text: (root.searchQuery !== "" || root.filterMode !== "all") && notificationService && notificationService.historyList && notificationService.historyList.count > 0 ? "No matching notifications" : "All caught up!"
                        font.bold: true
                        color: Theme.fg
                        Layout.alignment: Qt.AlignHCenter
                    }

                    ThemedText {
                        text: (root.searchQuery !== "" || root.filterMode !== "all") ? "Try another search or category." : "No new notifications at the moment."
                        customSize: Constants.sizeXs + 2
                        color: Theme.muted
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Constants.animNormal
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Item {
                    id: listContainer

                    anchors.fill: parent
                    visible: root.filteredEntries.length > 0 || root.isClearingAll
                    opacity: root.isClearingAll ? 0 : 1
                    x: root.isClearingAll ? 40 : 0
                    scale: root.isClearingAll ? 0.94 : 1
                    transformOrigin: Item.Center

                    ListView {
                        id: historyView

                        anchors.fill: parent
                        interactive: true
                        model: root.filteredEntries
                        spacing: Constants.sizeXs

                        displaced: Transition {
                            NumberAnimation {
                                properties: "y"
                                duration: Constants.animNormal
                                easing.type: Easing.OutQuint
                            }

                        }

                        delegate: NotificationItemDelegate {
                            notifData: modelData.notifData
                            notificationService: root.notificationService
                            itemIndex: index
                            currentTime: root.currentTime
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutQuad
                        }

                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutCubic
                            onRunningChanged: {
                                if (!running && root.isClearingAll) {
                                    if (root.notificationService)
                                        root.notificationService.clearHistory();

                                    root.isClearingAll = false;
                                }
                            }
                        }

                    }

                }

            }

        }

    }

}
