import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Components as BarComponents

IslandBackground {
    id: root

    required property QtObject islandBar
    required property QtObject islandComponents
    required property Item centerPill
    property real openProgress: 0
    readonly property bool isTarget: islandBar.activeIslandTarget === "left" && (islandBar.isOpen || islandBar.isRemoving)
    readonly property bool workspaceEventActive: SettingsService.islandLeftWidget === "workspaces" && IslandEventService.eventActive && IslandEventService.eventType === "workspace" && !islandBar.isOpen && !islandBar.hasActiveNotifications
    readonly property bool isHovered: leftHover.hovered && !islandBar.isOpen && openProgress === 0
    readonly property bool isTranslated: isHovered || isTarget || openProgress > 0
    readonly property real idleContentW: idleWidgetLoader.item ? Math.max(idleWidgetLoader.item.width, idleWidgetLoader.item.implicitWidth) : 32
    readonly property real idleW: Math.max(44, (idleContentW + 12) * SettingsService.islandLeftWidthScale / 100)
    readonly property real idleH: SettingsService.islandLeftHeight
    readonly property real idleR: Math.min(SettingsService.islandCornerRadius, idleH / 2)
    readonly property real panelW: isTarget ? islandComponents.getTargetWidth(islandBar.effectivePanel, leftLoader.item, 0) : idleW
    readonly property real panelH: isTarget ? islandComponents.getTargetHeight(islandBar.effectivePanel, leftLoader.item) : idleH
    readonly property real panelR: isTarget ? islandComponents.getTargetRadius(islandBar.effectivePanel) : idleR
    readonly property alias activeItem: leftLoader.item

    // The center event toast temporarily replaces the persistent workspace
    // capsule, avoiding the old and new workspace indicators appearing together.
    visible: !workspaceEventActive
    z: isTarget ? 10 : 1
    x: Math.max(16, centerPill.x - SettingsService.islandGap - width)
    y: 0
    width: idleW + (panelW - idleW) * openProgress
    height: idleH + (panelH - idleH) * openProgress
    radius: idleR + (panelR - idleR) * openProgress

    HoverHandler {
        id: leftHover

        enabled: !islandBar.isOpen && root.openProgress === 0
        margin: root.isHovered ? 8 : 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.openProgress > 0.05
    }

    Item {
        anchors.fill: parent
        opacity: Math.min(1, Math.max(0, 1 - root.openProgress / 0.15))
        visible: opacity > 0.001
        clip: true

        Loader {
            id: idleWidgetLoader
            anchors.centerIn: parent
            sourceComponent: SettingsService.islandLeftWidget === "workspaces" ? workspaceIdleComponent : sysmonIdleComponent
        }

        Component {
            id: sysmonIdleComponent
            BarComponents.SysMonIslandButton { }
        }

        Component {
            id: workspaceIdleComponent
            BarComponents.Workspaces {
                compact: true
                bgColor: "transparent"
                customHeight: 20
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Constants.sizeLg
        opacity: islandBar.isRemoving ? Math.min(1, Math.max(0, (root.openProgress - 0.4) / 0.6)) : Math.min(1, Math.max(0, (root.openProgress - 0.2) / 0.8))
        scale: islandBar.isRemoving ? (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.3) / 0.7))) : (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.15) / 0.85)))
        visible: opacity > 0.001
        clip: true

        Loader {
            id: leftLoader

            property real targetW: islandComponents.getContentWidth(islandBar.effectivePanel, item)
            property real targetH: islandComponents.getContentHeight(islandBar.effectivePanel, item)

            width: targetW > 0 ? targetW : parent.width
            height: targetH > 0 ? targetH : parent.height
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.isTarget
            sourceComponent: islandComponents.getComponent(islandBar.effectivePanel)
            onStatusChanged: {
                if (status === Loader.Ready && item) {
                    if (item.widget !== undefined)
                        item.widget = islandBar;

                }
            }
        }

    }

    transform: Translate {
        x: root.isTranslated ? -4 : 0
        y: root.isTranslated ? 4 : 0

        Behavior on x {
            enabled: HyprlandService.enableAnimations

            NumberAnimation {
                duration: Constants.animNormal
                easing.type: Easing.OutQuint
            }

        }

        Behavior on y {
            enabled: HyprlandService.enableAnimations

            NumberAnimation {
                duration: Constants.animNormal
                easing.type: Easing.OutQuint
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
