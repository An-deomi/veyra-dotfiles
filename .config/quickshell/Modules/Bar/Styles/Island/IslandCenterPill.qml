import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Components as BarComponents

IslandBackground {
    id: root

    required property QtObject islandBar
    required property QtObject islandComponents
    required property Item islandContainer
    required property var notificationService
    property real openProgress: 0
    readonly property bool isTarget: islandBar.activeIslandTarget === "center" && (islandBar.isOpen || islandBar.isRemoving)
    readonly property bool hasActiveNotifications: notifLayer.hasActiveNotifications
    readonly property bool isRemovingNotif: notifLayer.isRemovingNotif
    property real notifProgress: (hasActiveNotifications && !isRemovingNotif) ? 1 : 0
    // Keep the pill laid out for the toast until its fade-out finishes, so the
    // capsule cannot collapse out from under a still-visible toast.
    readonly property bool showEventToast: (IslandEventService.eventActive || eventToast.opacity > 0.001) && !islandBar.isOpen && !hasActiveNotifications
    readonly property bool isHovered: centerHover.hovered && !islandBar.isOpen && openProgress === 0 && !hasActiveNotifications && !showEventToast
    readonly property bool showWorkspacePreview: !islandBar.isOpen && openProgress === 0 && !hasActiveNotifications && !showEventToast && SettingsService.islandCenterWidget === "workspaces"
    readonly property bool showClock: !showEventToast && SettingsService.islandCenterWidget !== "workspaces" && !showWorkspacePreview
    readonly property bool isTranslated: isHovered || isTarget || openProgress > 0 || (hasActiveNotifications && notifProgress > 0)
    readonly property real notifW: notifLayer.notifW
    readonly property real notifH: notifLayer.notifH
    readonly property real notifR: Constants.sizeXl
    // Grow to accommodate both the clock and the workspace module. Unlike a
    // replacement preview, this keeps a stable, clickable clock target.
    readonly property real idleContentWidth: showEventToast ? eventToast.implicitWidth : (showWorkspacePreview ? workspacePreview.implicitWidth : (showClock ? clockContent.implicitWidth : 0))
    readonly property real idleW: (idleContentWidth + 20) * SettingsService.islandCenterWidthScale / 100
    readonly property real idleH: SettingsService.islandCenterHeight
    readonly property real idleR: Math.min(SettingsService.islandCornerRadius, idleH / 2)
    property real smoothIdleW: idleW
    readonly property real panelW: isTarget ? islandComponents.getTargetWidth(islandBar.effectivePanel, centerLoader.item, 0) : smoothIdleW
    readonly property real panelH: isTarget ? islandComponents.getTargetHeight(islandBar.effectivePanel, centerLoader.item) : idleH
    readonly property real panelR: isTarget ? islandComponents.getTargetRadius(islandBar.effectivePanel) : idleR
    readonly property real baseW: smoothIdleW + (notifW - smoothIdleW) * notifProgress
    readonly property real baseH: idleH + (notifH - idleH) * notifProgress
    readonly property real baseR: idleR + (notifR - idleR) * notifProgress
    property real smoothPanelW: panelW
    property real smoothPanelH: panelH
    property real smoothPanelR: panelR
    readonly property alias activeItem: centerLoader.item

    function restartDisplayTimer() {
        notifLayer.restartDisplayTimer();
    }

    z: isTarget ? 10 : 1
    x: Math.round((islandContainer.width - width) / 2)
    y: 0
    width: baseW + (smoothPanelW - baseW) * openProgress
    height: baseH + (smoothPanelH - baseH) * openProgress
    radius: baseR + (smoothPanelR - baseR) * openProgress

    HoverHandler {
        id: centerHover

        enabled: false
        margin: 0
    }

    // Fallback click target for the capsule's empty space. It sits behind the
    // clock and workspace slots, so their own mouse handlers keep priority.
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: root.openProgress < 0.05 && !root.hasActiveNotifications && root.showClock
        onClicked: (mouse) => AppState.toggleWidget(
            mouse.button === Qt.RightButton ? "controlCenter" : "clock"
        )
    }

    Row {
        id: idleModules

        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        z: 1
        spacing: 0

        BarComponents.Workspaces {
            id: workspacePreview

            compact: true
            bgColor: "transparent"
            visible: root.showWorkspacePreview
            width: root.showWorkspacePreview ? implicitWidth : 0
            opacity: visible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        IslandClock {
            id: clockContent

            clickable: !islandBar.isOpen && !root.hasActiveNotifications
            clickWidget: "clock"
            width: root.showClock ? implicitWidth : 0
            opacity: root.showClock ? Math.min(1, Math.max(0, 1 - Math.max(root.openProgress, root.notifProgress) / 0.15)) : 0
            visible: opacity > 0.001

            Behavior on opacity {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    BarComponents.EventToast {
        id: eventToast
        anchors.centerIn: parent
        visible: root.showEventToast
        z: 3
    }

    IslandNotifLayer {
        id: notifLayer

        notificationService: root.notificationService
        isHostPanel: islandBar.isHostPanel
        openProgress: root.openProgress
        notifProgress: root.notifProgress
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
    }

    Item {
        anchors.fill: parent
        anchors.margins: islandComponents.getTargetPadding(islandBar.effectivePanel)
        opacity: islandBar.isRemoving ? Math.min(1, Math.max(0, (root.openProgress - 0.4) / 0.6)) : Math.min(1, Math.max(0, (root.openProgress - 0.2) / 0.8))
        scale: islandBar.isRemoving ? (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.3) / 0.7))) : (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.15) / 0.85)))
        visible: opacity > 0.001
        clip: true

        Loader {
            id: centerLoader

            property real targetW: islandComponents.getContentWidth(islandBar.effectivePanel, item)
            property real targetH: islandComponents.getContentHeight(islandBar.effectivePanel, item)

            width: targetW > 0 ? targetW : parent.width
            height: targetH > 0 ? targetH : parent.height
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.isTarget
            sourceComponent: islandComponents.getComponent(islandBar.effectivePanel)
            opacity: status === Loader.Ready ? 1 : 0
            onStatusChanged: {
                if (status === Loader.Ready && item) {
                    if (item.widget !== undefined)
                        item.widget = islandBar;

                    islandBar.triggerFocus();
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    transform: Translate {
        y: root.isTranslated ? 4 : 0

        Behavior on y {
            enabled: HyprlandService.enableAnimations

            NumberAnimation {
                duration: Constants.animNormal
                easing.type: Easing.OutQuint
            }

        }

    }

    Behavior on smoothIdleW {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothPanelW {
        enabled: HyprlandService.enableAnimations && root.openProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothPanelH {
        enabled: HyprlandService.enableAnimations && root.openProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothPanelR {
        enabled: HyprlandService.enableAnimations && root.openProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on notifProgress {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: root.isRemovingNotif ? Constants.animFast : Constants.animNormal
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (!running && root.isRemovingNotif) {
                    notifLayer.isRemovingNotif = false;
                    notifLayer.dismissActiveNotifications();
                }
            }
        }

    }

    Behavior on openProgress {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: islandBar.isRemoving ? Constants.animNormal : Constants.animExpressive
            easing.type: islandBar.isRemoving ? Easing.OutCubic : Easing.OutQuint
            onRunningChanged: {
                if (!running && islandBar.isRemoving)
                    islandBar.checkFinishClosing();

            }
        }

    }

}
