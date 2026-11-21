import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Modules.Bar
import qs.Modules.Bar.Components

PanelWindow {
    id: root

    required property var notificationService
    property bool isShellReady: false
    property string activeBarStyle: "convex"
    readonly property bool isConvexMode: SettingsService.barConvexMode
    readonly property bool isExiting: !isConvexMode
    property int barHeight: BarStyleConfig.barHeight("convex")
    property real animatedBarHeight: barHeight
    property int bezelSize: DisplayProfileService.gameModeActive ? 0 : (SettingsService.convexFrameEnabled ? SettingsService.convexFrameSize : 0)
    property bool hasFullscreen: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen) ? HyprlandService.isTrueFullscreen : false
    property real fsTransitionProg: hasFullscreen ? 0 : 1
    readonly property var convexPanels: convexPanelsLoader.item
    readonly property bool needsFocus: (AppState.isFocusWidgetOpen && convexPanels && convexPanels.hasAnyDrawerOpen) || AppState.textInputActive

    function triggerStyleSwitch() {
        root.activeBarStyle = SettingsService.barStyle;
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: needsFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    focusable: needsFocus
    surfaceFormat.opaque: false
    color: "transparent"
    Component.onCompleted: {
        activeBarStyle = SettingsService.barStyle;
        Qt.callLater(() => {
            isShellReady = true;
        });
    }
    onVisibleChanged: {
        if (visible && SettingsService.barStyle === "convex") {
            shellFrameContainer.enableTransitionAnim = false;
            root.activeBarStyle = "convex";
            barContainer.switchOpacity = 1;
            barContainer.scale = 1;
            convexBarTranslate.y = 0;
        }
    }

    Connections {
        function onSettingsLoadedChanged() {
            if (SettingsService.settingsLoaded)
                root.activeBarStyle = SettingsService.barStyle;

        }

        function onBarStyleChanged() {
            root.triggerStyleSwitch();
        }

        target: SettingsService
    }

    Process {
        id: slurpCheckProcess

        command: ["sh", "-c", "pidof slurp"]
        onExited: {
            if (exitCode !== 0) {
                if (AppState.activeWidget !== "")
                    AppState.activeWidget = "";

            }
        }
    }

    HyprlandFocusGrab {
        id: surfaceFocusGrab

        active: root.focusable
        windows: [root]
        onCleared: {
            slurpCheckProcess.running = true;
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    ConvexExclusions {
        hasFullscreen: root.hasFullscreen
        barHeight: root.barHeight
        bezelSize: root.bezelSize
        isExiting: root.isExiting
    }

    Item {
        id: unifiedShadowGroup

        anchors.fill: parent
        opacity: root.isConvexMode ? 1 : 0
        layer.enabled: SettingsService.convexShadowEnabled && HyprlandService.hyprShadow && !DisplayProfileService.gameModeActive && (SystemInfoService.effectivePowerProfile !== "power-saver")

        Loader {
            id: convexPanelsLoader
            anchors.fill: parent
            active: root.visible && root.isConvexMode
            z: 1
            sourceComponent: Component {
                ConvexPanels {
                    anchors.fill: parent
                    barHeight: root.barHeight
                    bezelSize: root.bezelSize
                    notificationService: root.notificationService
                }
            }
        }

        ConvexFrameBezel {
            id: shellFrameContainer

            z: 21
            hasFrame: SettingsService.convexFrameEnabled
            isShellReady: root.isShellReady
            barHeight: Math.round(root.animatedBarHeight)
            activeBarStyle: root.activeBarStyle
            bezelSize: root.bezelSize
            fsTransitionProg: root.fsTransitionProg
            leftW: (barContainer.activeItem && barContainer.activeItem.leftWidth) ? barContainer.activeItem.leftWidth : 0
            centerX: (barContainer.activeItem && barContainer.activeItem.centerX) ? barContainer.activeItem.centerX : 0
            centerW: (barContainer.activeItem && barContainer.activeItem.centerWidth) ? barContainer.activeItem.centerWidth : 0
            rightW: (barContainer.activeItem && barContainer.activeItem.rightWidth) ? barContainer.activeItem.rightWidth : 0
            centerHeight: (barContainer.activeItem && barContainer.activeItem.centerHeight) ? barContainer.activeItem.centerHeight : Math.round(root.animatedBarHeight)
            centerBottomRadius: (barContainer.activeItem && barContainer.activeItem.centerBottomRadius !== undefined) ? barContainer.activeItem.centerBottomRadius : SettingsService.convexCornerRadius
        }

        Item {
            id: barContainer

            property QtObject activeItem: convexLoader.item
            property real switchOpacity: 1

            z: 20
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: (activeItem && (activeItem.centerHeight || 0) > root.barHeight) ? activeItem.centerHeight : root.barHeight
            transformOrigin: Item.Top
            opacity: root.fsTransitionProg * switchOpacity
            visible: opacity > 0.01
            transform: [
                Translate {
                    id: convexBarTranslate

                    y: 0
                }
            ]

            Loader {
                id: convexLoader

                anchors.fill: parent
                active: root.visible && root.isConvexMode
                visible: root.visible && root.isConvexMode
                source: "ConvexBar.qml"
                onLoaded: {
                    if (item) {
                        item.notificationService = root.notificationService;
                        item.mainPanelWidget = Qt.binding(() => {
                            return root.convexPanels ? root.convexPanels.dashboardWidget : null;
                        });
                        item.controlCenterWidget = Qt.binding(() => {
                            return root.convexPanels ? root.convexPanels.controlCenterWidget : null;
                        });
                        item.notificationsCenterWidget = Qt.binding(() => {
                            return root.convexPanels ? root.convexPanels.notificationsCenterWidget : null;
                        });
                    }
                }
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }

        }

        layer.effect: MultiEffect {
            shadowEnabled: SettingsService.convexShadowEnabled
            shadowColor: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, Theme.isDark ? 1 : Math.min(1, Theme.shadow.a * 1.6))
            blurMax: HyprlandService.hyprShadowRange
            shadowBlur: 1
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
        }

    }

    Behavior on fsTransitionProg {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.InOutCubic
        }

    }

    mask: Region {
        // Top border + Bar
        Region {
            x: 0
            y: 0
            width: root.width
            height: root.barHeight * root.fsTransitionProg
        }

        // Left border
        Region {
            x: 0
            y: root.barHeight * root.fsTransitionProg
            width: root.bezelSize * root.fsTransitionProg
            height: root.height
        }

        // Right border
        Region {
            x: root.width - (root.bezelSize * root.fsTransitionProg)
            y: root.barHeight * root.fsTransitionProg
            width: root.bezelSize * root.fsTransitionProg
            height: root.height
        }

        // Bottom border
        Region {
            x: root.bezelSize * root.fsTransitionProg
            y: root.height - (root.bezelSize * root.fsTransitionProg)
            width: root.width - (2 * root.bezelSize * root.fsTransitionProg)
            height: root.bezelSize * root.fsTransitionProg
        }

        // Active Panels Overlay (Full Screen for Clicks/Focus)
        Region {
            property bool isActive: root.convexPanels
                && (root.convexPanels.hasAnyPanelOpen || root.convexPanels.isConvexCenterOpen)

            x: 0
            y: 0
            width: isActive ? root.width : 0
            height: isActive ? root.height : 0
        }

        // Convex Center Notch Expanded Region
        Region {
            readonly property bool isConvexExpanded: root.activeBarStyle === "convex" && barContainer.activeItem && (barContainer.activeItem.centerHeight > root.barHeight)
            readonly property real cX: (root.activeBarStyle === "convex" && barContainer.activeItem) ? (barContainer.activeItem.centerX || 0) : 0
            readonly property real cW: (root.activeBarStyle === "convex" && barContainer.activeItem) ? (barContainer.activeItem.centerWidth || 0) : 0
            readonly property real cH: (root.activeBarStyle === "convex" && barContainer.activeItem) ? (barContainer.activeItem.centerHeight || 0) : 0

            x: isConvexExpanded ? (cX - 8) : 0
            y: 0
            width: isConvexExpanded ? (cW + 16) : 0
            height: isConvexExpanded ? (cH + 16) : 0
        }

    }

}
