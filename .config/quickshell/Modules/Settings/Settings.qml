import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.Settings.BarSettings
import qs.Modules.Settings.Components
import qs.Modules.Settings.InputAndClipboardSettings
import qs.Modules.Settings.IntegrationsSettings
import qs.Modules.Settings.LockScreenSettings
import qs.Modules.Settings.MouseSettings
import qs.Modules.Settings.NotificationsSettings
import qs.Modules.Settings.ScreenCaptureSettings
import qs.Modules.Settings.DefaultAppsSettings
import qs.Modules.Settings.PersonalizationSettings
import qs.Modules.Settings.PowerSettings
import qs.Modules.Settings.StartupSettings
import qs.Modules.Settings.SystemInfo
import qs.Modules.Settings.WallpaperSettings
import qs.Modules.Settings.WindowSettings
import qs.Modules.Settings.HyprlandTools
import qs.Modules.Settings.ThemeStudio

AppWindow {
    id: root

    // Live NotificationService supplied by ShellModules.
    property var notificationService: null

    // Index 2 is the single Hyprland page. Index 3 remains an alias for older
    // internal tab references created by previous Veyra versions.
    property var pageComponents: [personalizationComp, barSettingsComp, windowComp, windowComp, integrationsComp, mouseComp, inputAndClipboardComp, systemInfoComp, wallpaperComp, lockScreenComp, notificationsComp, screenCaptureComp, defaultAppsComp, powerComp, startupComp, null, hyprToolsComp, themeStudioComp]
    property int activeTab: 0
    readonly property var navOrder: [0, 17, 8, 1, 2, 16, 5, 6, 9, 11, 13, 14, 4, 12, 10, 7]
    readonly property var tabMetadata: ({
        "0": {
            "title": "Appearance",
            "subtitle": "System typography and application theme integrations",
            "category": "PERSONALIZATION"
        },
        "1": {
            "title": "Shell",
            "subtitle": "Configure Veyra's panels, widgets, and shell appearance",
            "category": "VEYRA SHELL"
        },
        "2": {
            "title": "Hyprland",
            "subtitle": "Manage layouts, windows, compositor effects, and motion",
            "category": "COMPOSITOR"
        },
        "3": {
            "title": "Hyprland",
            "subtitle": "Manage layouts, windows, compositor effects, and motion",
            "category": "COMPOSITOR"
        },
        "4": {
            "title": "Integrations & Apps",
            "subtitle": "Weather service, GitHub status, notifications, and launcher",
            "category": "APPS & SERVICES"
        },
        "5": {
            "title": "Mouse & Touchpad",
            "subtitle": "Cursor speed, acceleration, scrolling, and touchpad gestures",
            "category": "INPUT"
        },
        "6": {
            "title": "Keyboard & Clipboard",
            "subtitle": "Keyboard layouts, repeat delay, and clipboard history",
            "category": "INPUT"
        },
        "7": {
            "title": "About System",
            "subtitle": "Hardware specifications, kernel, and software environment",
            "category": "ABOUT"
        },
        "8": {
            "title": "Wallpaper",
            "subtitle": "Screen crop preview, scaling modes, transitions, and shuffle",
            "category": "PERSONALIZATION"
        },
        "9": {
            "title": "Lock Screen",
            "subtitle": "Configure lock screen appearance, idle timeouts, and power behavior",
            "category": "SYSTEM"
        },
        "10": {
            "title": "Notifications",
            "subtitle": "Popups, do not disturb, grouping, and notification history",
            "category": "APPS & SERVICES"
        },
        "11": {
            "title": "Screen Capture",
            "subtitle": "Recording audio sources and output resolution",
            "category": "SYSTEM"
        },
        "12": {
            "title": "Default Apps",
            "subtitle": "Choose the apps used by Veyra and the Linux desktop",
            "category": "APPS & SERVICES"
        },
        "13": {
            "title": "Power & Battery",
            "subtitle": "Performance profiles and battery health at a glance",
            "category": "SYSTEM"
        },
        "14": {
            "title": "Startup Applications",
            "subtitle": "Choose which desktop applications start with your session",
            "category": "SYSTEM"
        },
        "16": {
            "title": "Window Rules & Displays",
            "subtitle": "Configure per-app behavior and saved monitor layouts",
            "category": "COMPOSITOR"
        },
        "17": {
            "title": "Theme Studio",
            "subtitle": "Build, preview, and save Veyra color palettes",
            "category": "PERSONALIZATION"
        }
    })
    readonly property var currentTabMeta: tabMetadata[activeTab] || tabMetadata[0]

    // Open as a compact utility window instead of filling the entire monitor.
    implicitWidth: 1180
    implicitHeight: 760
    minimumSize: Qt.size(920, 600)
    maximumSize: Qt.size(1440, 920)

    widgetId: "veyra_settings"
    windowTitle: "Veyra Settings"
    contentPadding: 0
    onIsOpenChanged: {
        if (isOpen) {
            if (AppState.pendingSettingsTab !== -1) {
                activeTab = AppState.pendingSettingsTab;
                AppState.pendingSettingsTab = -1;
            } else {
                activeTab = 0;
            }
        }
    }

    // Hands a search jump to whichever page is on screen once it settled.
    Timer {
        id: jumpTimer

        property string label: ""
        property string group: ""

        interval: 0

        onTriggered: {
            AppState.pendingSettingLabel = label;
            AppState.pendingSettingGroup = group;
            if (pageLoader.item && typeof pageLoader.item.applyPendingFocus === "function")
                pageLoader.item.applyPendingFocus();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        SettingsSidebar {
            id: sidebar

            Layout.fillHeight: true
            activeTab: root.activeTab
            onTabClicked: (id) => {
                root.activeTab = id;
            }
            onSettingClicked: (page, label, group) => {
                let samePage = root.activeTab === page;
                root.activeTab = page;
                // After a tab change the old page is still alive for the
                // crossfade and could eat the request, so wait for the
                // transition to finish before handing it over.
                jumpTimer.label = label;
                jumpTimer.group = group;
                jumpTimer.interval = samePage ? 0 : 420;
                jumpTimer.restart();
            }
        }

        ColumnLayout {
            id: contentContainer

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            AppHeader {
                title: root.currentTabMeta.title
                category: root.currentTabMeta.category
                subtitle: root.currentTabMeta.subtitle
                showDivider: true
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                PageTransitionView {
                    anchors.fill: parent
                    activeIndex: root.activeTab
                    order: root.navOrder
                    onContentNeedsUpdate: (index) => {
                        pageLoader.sourceComponent = root.pageComponents[index];
                    }

                    Loader {
                        id: pageLoader

                        anchors.fill: parent
                        sourceComponent: personalizationComp
                    }

                }

            }

        }

    }

    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: root.isOpen && root.pageComponents && root.pageComponents.length > 1
        onActivated: {
            let currentIdx = root.navOrder.indexOf(root.activeTab);
            if (currentIdx === -1)
                currentIdx = 0;

            let nextIdx = (currentIdx + 1) % root.navOrder.length;
            root.activeTab = root.navOrder[nextIdx];
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: root.isOpen && root.pageComponents && root.pageComponents.length > 1
        onActivated: {
            let currentIdx = root.navOrder.indexOf(root.activeTab);
            if (currentIdx === -1)
                currentIdx = 0;

            let prevIdx = (currentIdx - 1 + root.navOrder.length) % root.navOrder.length;
            root.activeTab = root.navOrder[prevIdx];
        }
    }

    Component {
        id: personalizationComp

        PersonalizationSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: barSettingsComp

        BarSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: windowComp

        WindowSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: integrationsComp

        IntegrationsSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: mouseComp

        MouseSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: inputAndClipboardComp

        InputAndClipboardSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: systemInfoComp

        SystemInfo {
            anchors.fill: parent
        }

    }

    Component {
        id: wallpaperComp

        WallpaperSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: lockScreenComp

        LockScreenSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: notificationsComp

        NotificationsSettings {
            anchors.fill: parent
            notificationService: root.notificationService
        }

    }


    // Screen Capture settings page (v35)
    Component {
        id: screenCaptureComp

        ScreenCaptureSettings {
            anchors.fill: parent
        }
    }

    Component {
        id: defaultAppsComp

        DefaultAppsSettings {
            anchors.fill: parent
        }
    }

    Component {
        id: powerComp

        PowerSettings {
            anchors.fill: parent
        }
    }

    Component {
        id: startupComp

        StartupSettings {
            anchors.fill: parent
        }
    }


    Component {
        id: hyprToolsComp

        HyprlandToolsSettings {
            anchors.fill: parent
        }
    }


    Component {
        id: themeStudioComp

        ThemeStudioSettings {
            anchors.fill: parent
        }
    }

}
