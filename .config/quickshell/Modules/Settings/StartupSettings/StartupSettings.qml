import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    pageTitle: "Startup Applications"
    pageDescription: "Choose which desktop applications launch automatically when you sign in."
    pageIcon: "rocket"

    property string listOutput: ""
    property string actionOutput: ""
    property string statusText: "Reading your autostart entries…"
    property bool busy: false

    function reloadEntries() {
        if (listProcess.running)
            return;
        root.listOutput = "";
        root.statusText = "Scanning ~/.config/autostart…";
        listProcess.running = true;
    }

    function parseEntries() {
        try {
            const entries = JSON.parse(root.listOutput || "[]");
            startupModel.clear();
            for (let i = 0; i < entries.length; i++) {
                const entry = entries[i];
                startupModel.append({
                    appId: String(entry.id || ""),
                    appName: String(entry.name || entry.id || "Startup application"),
                    appComment: String(entry.comment || ""),
                    appExec: String(entry.exec || ""),
                    appEnabled: Boolean(entry.enabled)
                });
            }
            root.statusText = entries.length === 0
                ? "No XDG autostart entries were found."
                : entries.length + " startup entries found";
        } catch (error) {
            root.statusText = "Could not parse startup applications: " + error;
        }
    }

    function setEntryEnabled(entryId, enabled) {
        if (root.busy)
            return;
        root.busy = true;
        root.actionOutput = "";
        actionProcess.command = ["python3", Quickshell.shellDir + "/Scripts/system/startup_apps.py", "set", entryId, enabled ? "true" : "false"];
        actionProcess.running = true;
    }

    ListModel {
        id: startupModel
    }

    Process {
        id: listProcess
        command: ["python3", Quickshell.shellDir + "/Scripts/system/startup_apps.py", "list"]

        stdout: SplitParser {
            onRead: (data) => root.listOutput += data
        }
        stderr: SplitParser {
            onRead: (data) => root.statusText = data.trim()
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                root.parseEntries();
            else
                root.statusText = "Could not inspect startup applications. Check the Quickshell log.";
        }
    }

    Process {
        id: actionProcess
        command: []

        stdout: SplitParser {
            onRead: (data) => root.actionOutput += data
        }
        stderr: SplitParser {
            onRead: (data) => root.actionOutput += data
        }
        onExited: function(exitCode, exitStatus) {
            root.busy = false;
            try {
                const result = JSON.parse(root.actionOutput || "{}");
                root.statusText = result.message || (exitCode === 0 ? "Startup preference updated." : "Could not update startup preference.");
            } catch (error) {
                root.statusText = exitCode === 0 ? "Startup preference updated." : "Could not update startup preference.";
            }
            root.actionOutput = "";
            root.reloadEntries();
        }
    }

    Component.onCompleted: reloadEntries()

    AppGroup {
        title: "Login Applications"
        icon: "rocket"
        badge: startupModel.count + " entries"

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedText {
                Layout.fillWidth: true
                text: root.statusText
                customSize: Constants.sizeXs + 1
                color: Theme.muted
                wrapMode: Text.WordWrap
            }

            ThemeButton {
                text: "Refresh"
                enabled: !root.busy && !listProcess.running
                onClicked: root.reloadEntries()
            }
        }

        Repeater {
            model: startupModel

            delegate: Item {
                id: entryRoot
                required property string appId
                required property string appName
                required property string appComment
                required property string appExec
                required property bool appEnabled

                Layout.fillWidth: true
                implicitHeight: 76

                Card {
                    anchors.fill: parent
                    contentPadding: Constants.sizeMd
                    cardRadius: Constants.sizeSm
                    useBorder: true
                    backgroundColor: Theme.bgTertiary

                    RowLayout {
                        anchors.fill: parent
                        spacing: Constants.sizeMd

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: Constants.sizeSm
                            color: Theme.bgAccent

                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "apps"
                                iconSize: Constants.sizeLg
                                iconColor: Theme.accent
                                flat: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Constants.size3Xs

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Constants.sizeXs

                                ThemedText {
                                    Layout.fillWidth: true
                                    text: entryRoot.appName
                                    customSize: Constants.sizeSm + 1
                                    font.weight: Font.DemiBold
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }

                                ThemedText {
                                    text: entryRoot.appEnabled ? "ENABLED" : "DISABLED"
                                    customSize: Constants.size3Xs + 2
                                    font.bold: true
                                    color: entryRoot.appEnabled ? Theme.accent : Theme.muted
                                }
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                text: entryRoot.appComment || entryRoot.appExec || entryRoot.appId
                                customSize: Constants.sizeXs + 1
                                color: Theme.muted
                                elide: Text.ElideRight
                            }
                        }

                        ThemeButton {
                            text: entryRoot.appEnabled ? "Disable" : "Enable"
                            enabled: !root.busy
                            onClicked: root.setEntryEnabled(entryRoot.appId, !entryRoot.appEnabled)
                        }
                    }
                }
            }
        }

        GhostEmptyState {
            Layout.fillWidth: true
            visible: startupModel.count === 0 && !listProcess.running
            icon: "rocket"
            text: "No startup applications"
            isAnimating: false
        }
    }

    AppGroup {
        title: "How this works"
        icon: "info"

        ThemedText {
            Layout.fillWidth: true
            text: "This page manages only your user-level XDG autostart entries in ~/.config/autostart. Disabling an entry marks its desktop file as hidden; it does not uninstall the application or remove the file. Hyprland startup commands in your Lua configuration are left untouched."
            customSize: Constants.sizeXs + 1
            color: Theme.muted
            wrapMode: Text.WordWrap
        }
    }
}
