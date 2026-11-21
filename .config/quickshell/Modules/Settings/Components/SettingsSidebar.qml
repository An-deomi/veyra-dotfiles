import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

AppSidebar {
    id: sidebarRoot

    property int activeTab: 0
    property string filterText: ""
    // Individual controls matching the query, from Scripts/settings/search_settings.py.
    property var settingMatches: []
    signal tabClicked(int index)
    // A control-level match was clicked: open its page and jump to the row.
    signal settingClicked(int page, string label, string group)

    onFilterTextChanged: {
        if (filterText.trim() === "") {
            settingMatches = [];
            searchDebounce.stop();
            return ;
        }
        searchDebounce.restart();
    }

    Timer {
        id: searchDebounce

        interval: 180
        repeat: false
        onTriggered: searchProc.running = true
    }

    Process {
        id: searchProc

        command: ["python3", Quickshell.shellDir + "/Scripts/settings/search_settings.py", sidebarRoot.filterText]
        running: false

        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let parsed = JSON.parse(data.trim());
                    sidebarRoot.settingMatches = Array.isArray(parsed) ? parsed : [];
                } catch (e) {
                    sidebarRoot.settingMatches = [];
                }
            }
        }
    }

    title: "VEYRA"
    subtitle: "SYSTEM CONFIGURATION"

    readonly property var sections: [
        { title: "PERSONALIZATION", items: [
            { id: 0, label: "Appearance", icon: "color-palette", keywords: "font typography app templates" },
            { id: 17, label: "Theme Studio", icon: "palette", keywords: "theme colors palette accent wallpaper presets preview import export" },
            { id: 8, label: "Wallpaper", icon: "picture", keywords: "background image transition shuffle" },
        ]},
        { title: "VEYRA SHELL", items: [
            { id: 1, label: "Shell", icon: "bar", keywords: "quickshell panel bar widgets island tray opacity" }
        ]},
        { title: "COMPOSITOR", items: [
            { id: 2, label: "Hyprland", icon: "monitor", keywords: "window layout dwindle master gaps blur opacity shadows animations effects borders" },
            { id: 16, label: "Window Rules & Displays", icon: "monitor-cog", keywords: "window rules application class title float pin opacity blur shadow animation monitor display resolution refresh rate scale rotation profile" }
        ]},
        { title: "INPUT", items: [
            { id: 5, label: "Mouse & Touchpad", icon: "cursor", keywords: "pointer sensitivity scrolling gestures" },
            { id: 6, label: "Keyboard & Clipboard", icon: "keyboard", keywords: "layout repeat shortcuts clipboard" }
        ]},
        { title: "SYSTEM", items: [
            { id: 9, label: "Lock Screen", icon: "lock", keywords: "idle timeout lock appearance" },
            { id: 11, label: "Screen Capture", icon: "record-icon", keywords: "screenshot recording audio" },
            { id: 13, label: "Power & Battery", icon: "battery-charging", keywords: "performance profile energy" },
            { id: 14, label: "Startup Applications", icon: "rocket", keywords: "autostart login launch" }
        ]},
        { title: "APPS & SERVICES", items: [
            { id: 4, label: "Integrations & Apps", icon: "apps", keywords: "weather github music services" },
            { id: 12, label: "Default Apps", icon: "apps", keywords: "browser terminal editor file manager" },
            { id: 10, label: "Notifications", icon: "bell", keywords: "do not disturb popup history" }
        ]},
        { title: "ABOUT", items: [
            { id: 7, label: "About System", icon: "info", keywords: "hardware kernel system information" }
        ]}
    ]

    ThemedSearchBar {
        Layout.fillWidth: true
        Layout.leftMargin: Constants.sizeSm
        Layout.rightMargin: Constants.sizeSm
        Layout.bottomMargin: Constants.sizeXs
        Layout.preferredHeight: 38
        autoFocus: false
        customSize: Constants.sizeXs + 2
        placeholderText: "Search settings..."
        onSearchRequested: (value) => sidebarRoot.filterText = value
    }

    Repeater {
        model: sidebarRoot.sections

        delegate: ColumnLayout {
            id: sectionRoot

            required property var modelData
            readonly property var filteredItems: {
                const query = sidebarRoot.filterText.trim().toLowerCase();
                return modelData.items.filter((entry) => {
                    const searchable = (entry.label + " " + (entry.keywords || "")).toLowerCase();
                    return query === "" || searchable.includes(query);
                });
            }

            Layout.fillWidth: true
            spacing: Constants.size3Xs
            visible: filteredItems.length > 0

            ThemedText {
                text: sectionRoot.modelData.title
                customSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.8
                color: Theme.muted
                Layout.leftMargin: Constants.sizeLg
                Layout.topMargin: Constants.sizeSm
                Layout.bottomMargin: Constants.size2Xs
            }

            Repeater {
                model: sectionRoot.filteredItems

                delegate: Item {
                    id: navItem
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.leftMargin: Constants.sizeSm
                    Layout.rightMargin: Constants.sizeSm
                    Layout.preferredHeight: 36

                    SidebarNavRow {
                        anchors.fill: parent
                        iconName: navItem.modelData.icon
                        labelText: navItem.modelData.label
                        isActive: sidebarRoot.activeTab === navItem.modelData.id
                        onRowClicked: sidebarRoot.tabClicked(navItem.modelData.id)
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: sidebarRoot.filterText.trim() !== "" && sidebarRoot.settingMatches.length > 0
        spacing: Constants.size3Xs

        ThemedText {
            text: "CONTROLS"
            customSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 0.8
            color: Theme.muted
            Layout.leftMargin: Constants.sizeLg
            Layout.topMargin: Constants.sizeSm
            Layout.bottomMargin: Constants.size2Xs
        }

        Repeater {
            model: sidebarRoot.settingMatches

            delegate: Item {
                id: controlItem
                required property var modelData

                Layout.fillWidth: true
                Layout.leftMargin: Constants.sizeSm
                Layout.rightMargin: Constants.sizeSm
                Layout.preferredHeight: 36

                SidebarNavRow {
                    anchors.fill: parent
                    iconName: "sliders"
                    labelText: controlItem.modelData.pageTitle + " · " + controlItem.modelData.label
                    isActive: false
                    onRowClicked: sidebarRoot.settingClicked(controlItem.modelData.page, controlItem.modelData.label, controlItem.modelData.group || "")
                }
            }
        }
    }

    ThemedText {
        visible: sidebarRoot.filterText.trim() !== "" && sidebarRoot.settingMatches.length === 0 && sidebarRoot.sections.every((section) => !section.items.some((entry) => (entry.label + " " + (entry.keywords || "")).toLowerCase().includes(sidebarRoot.filterText.trim().toLowerCase())))
        text: "No settings found"
        customSize: Constants.sizeXs + 1
        color: Theme.muted
        Layout.leftMargin: Constants.sizeLg
        Layout.topMargin: Constants.sizeMd
    }

    Item {
        Layout.preferredHeight: Constants.sizeMd
    }
}
