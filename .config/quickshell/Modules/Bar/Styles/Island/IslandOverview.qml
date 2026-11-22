import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Widgets.SystemTray as STray

// Hover overview for the Island clock pill: workspaces with their running
// apps on the left, the system tray on the right.
Item {
    id: root

    property var widget: null
    property alias initialFocusItem: root
    property int selectedWsIndex: 0
    property int selectedAppIndex: -1
    readonly property int trayColumnWidth: 176
    readonly property int activeWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property var workspaceModel: {
        const groups = {};
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const top = tops[i];
            if (!top || !top.workspace || top.workspace.id <= 0)
                continue;

            const wsId = top.workspace.id;
            const ipc = top.lastIpcObject || {};
            const cls = (top.wayland && top.wayland.appId) ? top.wayland.appId : (ipc["class"] || "");
            let address = String(top.address || "");
            if (address !== "" && !address.startsWith("0x"))
                address = "0x" + address;

            if (!groups[wsId])
                groups[wsId] = [];

            groups[wsId].push({
                "address": address,
                "cls": cls,
                "title": top.title || cls,
                "wayland": top.wayland || root.findWaylandToplevel(address)
            });
        }
        if (!groups[activeWsId])
            groups[activeWsId] = [];

        return Object.keys(groups).map((k) => parseInt(k)).sort((a, b) => a - b).map((id) => ({
            "id": id,
            "active": id === activeWsId,
            "apps": groups[id]
        }));
    }

    function findWaylandToplevel(address) {
        if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values)
            return null;
        const list = ToplevelManager.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (!t || !t.HyprlandToplevel)
                continue;
            const raw = String(t.HyprlandToplevel.address || "");
            const norm = raw.startsWith("0x") ? raw : ("0x" + raw);
            if (norm === address)
                return t;
        }
        return null;
    }

    function iconFor(cls) {
        const name = (cls || "").toString();
        if (name === "")
            return Quickshell.iconPath("application-x-executable", true) || "";

        const entry = DesktopEntries.heuristicLookup(name);
        if (entry && entry.icon) {
            if (entry.icon.startsWith("/"))
                return "file://" + entry.icon;

            const p = Quickshell.iconPath(entry.icon, true);
            if (p)
                return p;
        }
        return Quickshell.iconPath(name.toLowerCase(), true) || Quickshell.iconPath("application-x-executable", true) || "";
    }

    function closeSelf() {
        AppState.closeWidget("islandOverview");
    }

    function focusWorkspace(id) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        closeSelf();
    }

    function focusWindow(address) {
        if (/^0x[0-9a-f]+$/i.test(address))
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })");

        closeSelf();
    }

    function syncSelectionToActive() {
        const list = root.workspaceModel || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].active) {
                root.selectedWsIndex = i;
                root.selectedAppIndex = list[i].apps.length > 0 ? 0 : -1;
                return;
            }
        }
        root.selectedWsIndex = 0;
        root.selectedAppIndex = (list.length > 0 && list[0].apps.length > 0) ? 0 : -1;
    }

    function stepWorkspace(delta) {
        const list = root.workspaceModel || [];
        if (list.length === 0)
            return;
        const nextWs = (root.selectedWsIndex + delta + list.length) % list.length;
        root.selectedWsIndex = nextWs;
        root.selectedAppIndex = list[nextWs].apps.length > 0 ? 0 : -1;
    }

    function stepItem(delta) {
        const list = root.workspaceModel || [];
        if (list.length === 0)
            return;
        const wsIdx = Math.max(0, Math.min(root.selectedWsIndex, list.length - 1));
        const apps = list[wsIdx].apps || [];
        if (apps.length > 0) {
            const nextApp = root.selectedAppIndex + delta;
            if (nextApp >= 0 && nextApp < apps.length) {
                root.selectedAppIndex = nextApp;
                return;
            }
        }
        const nextWs = (wsIdx + delta + list.length) % list.length;
        root.selectedWsIndex = nextWs;
        const nextApps = list[nextWs].apps || [];
        root.selectedAppIndex = nextApps.length > 0 ? (delta > 0 ? 0 : nextApps.length - 1) : -1;
    }

    function activateSelected() {
        const list = root.workspaceModel || [];
        if (list.length === 0)
            return;
        const wsIdx = Math.max(0, Math.min(root.selectedWsIndex, list.length - 1));
        const ws = list[wsIdx];
        if (root.selectedAppIndex >= 0 && root.selectedAppIndex < ws.apps.length)
            root.focusWindow(ws.apps[root.selectedAppIndex].address);
        else
            root.focusWorkspace(ws.id);
    }

    implicitWidth: 680
    implicitHeight: Math.max(wsColumn.implicitHeight, trayColumn.implicitHeight)
    focus: true
    Component.onCompleted: {
        Hyprland.refreshToplevels();
        syncSelectionToActive();
        root.forceActiveFocus();
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Down) {
            root.stepWorkspace(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.stepWorkspace(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            root.stepItem(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
            root.stepItem(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activateSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.closeSelf();
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Constants.sizeLg

        // ── Workspaces ──────────────────────────────────────────────
        ColumnLayout {
            id: wsColumn

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Constants.size2Xs

            ThemedText {
                text: "WORKSPACES"
                customSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.8
                color: Theme.muted
                Layout.leftMargin: Constants.size2Xs
                Layout.bottomMargin: Constants.size2Xs
            }

            Repeater {
                model: root.workspaceModel

                delegate: Rectangle {
                    id: wsRow

                    required property var modelData
                    required property int index
                    readonly property bool isSelectedRow: root.selectedWsIndex === index

                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.apps.length > 0 ? 84 : 40
                    radius: Constants.sizeSm
                    color: (modelData.active || isSelectedRow) ? Chrome.accentTint : (wsHover.hovered ? Theme.bgSecondary : "transparent")
                    border.width: isSelectedRow ? 1.5 : (modelData.active ? 1 : 0)
                    border.color: isSelectedRow ? Theme.accent : Chrome.accentTintStrong

                    HoverHandler {
                        id: wsHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.focusWorkspace(wsRow.modelData.id)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Constants.sizeXs
                        anchors.rightMargin: Constants.sizeSm
                        spacing: Constants.sizeSm

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: Constants.sizeXs
                            color: wsRow.modelData.active ? Theme.accent : Theme.bgSecondary

                            ThemedText {
                                anchors.centerIn: parent
                                text: wsRow.modelData.id
                                customSize: 12
                                font.weight: Font.Bold
                                color: wsRow.modelData.active ? Theme.bg : Theme.fg
                            }
                        }

                        Row {
                            spacing: Constants.sizeXs
                            Layout.fillWidth: true
                            clip: true

                            Repeater {
                                model: wsRow.modelData.apps

                                delegate: Rectangle {
                                    id: appChip

                                    required property var modelData
                                    required property int index
                                    readonly property bool isSelectedApp: wsRow.isSelectedRow && root.selectedAppIndex === index

                                    width: 116
                                    height: 70
                                    radius: Constants.sizeXs
                                    color: Theme.bgSecondary
                                    border.width: (appHover.hovered || isSelectedApp) ? 1.5 : 0
                                    border.color: Theme.accent
                                    clip: true
                                    scale: (appHover.hovered || isSelectedApp) ? 1.03 : 1

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        height: 48
                                        color: Theme.bgTertiary

                                        ScreencopyView {
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            captureSource: root.visible ? appChip.modelData.wayland : null
                                            constraintSize: Qt.size(232, 104)
                                            live: true
                                        }
                                    }

                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        height: 20
                                        spacing: 4

                                        Image {
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            sourceSize: Qt.size(28, 28)
                                            source: root.iconFor(appChip.modelData.cls)
                                            smooth: true
                                            asynchronous: true
                                        }

                                        ThemedText {
                                            Layout.fillWidth: true
                                            text: appChip.modelData.title || appChip.modelData.cls
                                            customSize: 10
                                            color: appHover.hovered ? Theme.fg : Theme.muted
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }

                                    HoverHandler {
                                        id: appHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: root.focusWindow(appChip.modelData.address)
                                    }

                                    ThemedTooltip {
                                        visible: appHover.hovered
                                        text: appChip.modelData.title
                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Constants.animFast
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            ThemedText {
                                visible: wsRow.modelData.apps.length === 0
                                text: "Empty"
                                customSize: 11
                                color: Theme.muted
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        ThemedText {
                            visible: wsRow.modelData.apps.length > 0
                            text: wsRow.modelData.apps.length
                            customSize: 11
                            font.weight: Font.DemiBold
                            color: wsRow.modelData.active ? Theme.accent : Theme.muted
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Constants.animFast
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: Constants.size2Xs
            Layout.bottomMargin: Constants.size2Xs
            color: Theme.border
        }

        // ── System tray ─────────────────────────────────────────────
        ColumnLayout {
            id: trayColumn

            Layout.preferredWidth: root.trayColumnWidth
            Layout.alignment: Qt.AlignTop
            spacing: Constants.size2Xs

            ThemedText {
                text: "TRAY"
                customSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.8
                color: Theme.muted
                Layout.leftMargin: Constants.size2Xs
                Layout.bottomMargin: Constants.size2Xs
            }

            Flow {
                Layout.preferredWidth: root.trayColumnWidth
                spacing: Constants.size2Xs

                Repeater {
                    model: SystemTray.items

                    delegate: STray.TrayItem {
                        trayItem: modelData
                        itemIndex: index
                        customHeight: 36
                        iconSize: 18
                        onClicked: (mouse) => {
                            const isMenuClick = mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && modelData.onlyMenu);
                            if (isMenuClick) {
                                // Swaps the capsule view to the tray menu in place.
                                AppState.activeTrayItem = modelData;
                                AppState.openWidget("systemTray_" + index);
                            }
                        }
                    }
                }
            }

            ThemedText {
                visible: SystemTray.items.values.length === 0
                text: "No tray apps"
                customSize: 11
                color: Theme.muted
                Layout.leftMargin: Constants.size2Xs
            }
        }
    }
}
