import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.Bar
import qs.Modules.Bar.Styles.Convex
import qs.Modules.Bar.Styles.Gaming
import qs.Modules.Polkit
import qs.Modules.Music

ShellRoot {
    id: root

    readonly property bool isGaming: DisplayProfileService.gameModeActive
    readonly property bool isConvex: SettingsService.barStyle === "convex"
    readonly property bool onGamingWorkspace: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.name === "gaming"

    IpcHandler {
        function toggle(widgetId: string) {
            AppState.toggleWidget(widgetId);
        }

        function open(widgetId: string) {
            AppState.openWidget(widgetId);
        }

        function close(widgetId: string) {
            AppState.closeWidget(widgetId);
        }

        target: "widgets"
    }

    IpcHandler {
        function toggle() {
            AppState.toggleWidget("sysmon");
        }

        target: "sysmon"
    }

    IpcHandler {
        function toggle() {
            DisplayProfileService.nightLightActive = !DisplayProfileService.nightLightActive;
            IslandEventService.showEvent(
                "nightlight",
                "Night Light",
                DisplayProfileService.nightLightActive ? (DisplayProfileService.nightLightTemperature + "K") : "Off",
                "moon",
                -1,
                1450
            );
        }

        target: "nightLight"
    }

    IpcHandler {
        function cycle() {
            SettingsService.cycleScreenShader();
        }

        target: "screenShader"
    }

    NotificationService {
        id: globalNotificationService
    }

    PanelWindow {
        id: barSurface

        surfaceFormat.opaque: false
        readonly property int barHeight: BarStyleConfig.barHeight(SettingsService.barStyle)
        readonly property int barMarginTop: BarStyleConfig.barMarginTop(SettingsService.barStyle)
        readonly property int barMarginSide: BarStyleConfig.barMarginSide(SettingsService.barStyle)

        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"
        focusable: false
        implicitHeight: !SettingsService.settingsLoaded ? 0 : (barMarginTop + barHeight)
        visible: SettingsService.settingsLoaded && !root.isGaming && !root.onGamingWorkspace

        anchors {
            top: true
            left: true
            right: true
        }

        mask: Region {
        }

    }

    PanelWindow {
        id: gamingBarSurface

        surfaceFormat.opaque: false
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: Constants.size3Xl + 2
        color: Theme.bg
        focusable: false
        implicitHeight: Constants.size3Xl + 2
        visible: SettingsService.settingsLoaded && root.isGaming

        anchors {
            top: true
            left: true
            right: true
        }

        Loader {
            anchors.fill: parent
            active: root.isGaming
            sourceComponent: Component {
                GamingBar {
                    anchors.fill: parent
                    notificationService: globalNotificationService
                }
            }
        }

    }

    BarOverlayWindow {
        notificationService: globalNotificationService
        barSurface: barSurface
        visible: SettingsService.settingsLoaded && !root.isConvex && !root.isGaming && !root.onGamingWorkspace
    }

    ConvexDesktop {
        id: convexDesktopSurface

        notificationService: globalNotificationService
        visible: SettingsService.settingsLoaded && root.isConvex && !root.isGaming && !root.onGamingWorkspace
    }

    GamingOverlay {
        id: gamingOverlaySurface

        notificationService: globalNotificationService
    }

    PolkitDialog {
    }

    DesktopCavaVisualizer {
        gameMode: root.isGaming
    }

    ShellModules {
        id: shellModules
        notificationService: globalNotificationService
    }

}
