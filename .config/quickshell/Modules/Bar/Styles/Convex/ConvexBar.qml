import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar
import qs.Modules.Bar.Components

Item {
    id: root

    property var notificationService: null
    property var mainPanelWidget: null
    property var controlCenterWidget: null
    property var notificationsCenterWidget: null
    readonly property real baseBarHeight: BarStyleConfig.barHeight("convex")
    readonly property real leftWidth: leftSection.width
    readonly property real rightWidth: rightSection.width
    readonly property real centerWidth: convexCenter.currentWidth
    readonly property real centerHeight: convexCenter.currentHeight
    readonly property real centerBottomRadius: convexCenter.currentRadius
    readonly property real centerX: Math.round((root.width - centerWidth) / 2)
    readonly property bool hasBezelFrame: !DisplayProfileService.gameModeActive && SettingsService.convexFrameEnabled && SettingsService.convexFrameSize > 0
    readonly property bool isOccupied: convexCenter.isOccupied
    readonly property bool isExpanded: true
    readonly property string activeBarStyle: "convex"

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.baseBarHeight

    ConvexShape {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(root.baseBarHeight, root.centerHeight)
        baseHeight: root.baseBarHeight
        leftW: root.leftWidth
        centerX: root.centerX
        centerW: root.centerWidth
        centerHeight: root.centerHeight
        rightW: root.rightWidth
        z: -1
        enableShadow: false
        centerBottomRadius: convexCenter.currentRadius
        // Shape defaults used to be local constants; every one is a setting now
        // so the notch can be tuned without editing QML.
        topBezel: SettingsService.convexTopInset
        flareWidth: SettingsService.convexNotchFlare
        flareHeight: Math.max(0, SettingsService.convexNotchFlare - 2)
        bottomRadius: SettingsService.convexCornerRadius
        color: Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, SettingsService.convexBackdropBlur ? SettingsService.convexBackgroundOpacity : 1)
        borderWidth: (!root.hasBezelFrame && SettingsService.convexBorderEnabled) ? SettingsService.convexBorderWidth : 0
        borderColor: SettingsService.convexBorderEnabled ? (SettingsService.convexBorderColorMode === "subtle" ? Theme.border : Theme.accent) : "transparent"
        useGradientBorder: !root.hasBezelFrame && SettingsService.convexBorderEnabled && SettingsService.convexBorderColorMode === "gradient"
    }

    BarLeftSection {
        id: leftSection

        anchors.left: parent.left
        anchors.top: parent.top
        height: root.baseBarHeight
        mainPanelWidget: root.mainPanelWidget
        notificationService: root.notificationService
        sidePadding: 36
        mainBar: root
        contentMargin: Constants.sizeXs
    }

    ConvexCenter {
        id: convexCenter

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        notificationService: root.notificationService
        mainBar: root
        extraPadding: Constants.size3Xl
    }

    BarRightSection {
        id: rightSection

        anchors.right: parent.right
        anchors.top: parent.top
        height: root.baseBarHeight
        notificationService: root.notificationService
        sidePadding: 36
        mainBar: root
        contentMargin: Constants.sizeXs
        controlCenterWidget: root.controlCenterWidget
        notificationsCenterWidget: root.notificationsCenterWidget
        showConvexSysmon: true
    }

}
