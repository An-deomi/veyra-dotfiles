import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils
import qs.Modules.Settings.Components

AppContainer {
    id: barSettingsRoot

    pageTitle: "Shell"
    pageDescription: "Configure Veyra itself: panel style, widget layout, transparency and shell behavior."
    pageIcon: "bar"

    // Widgets a bar slot can host. Order must match the defaults below.
    readonly property var widgetChoices: ["none", "workspaces", "media", "clock", "tray", "control_center", "recording"]
    readonly property var widgetNames: ({
        "none": "None",
        "workspaces": "Workspaces",
        "media": "Media",
        "clock": "Clock",
        "tray": "System Tray",
        "control_center": "Control Center",
        "recording": "Recording Badge"
    })

    function widgetIndex(value) {
        let idx = widgetChoices.indexOf(value);
        return idx === -1 ? 0 : idx;
    }

    function widgetAt(index) {
        return widgetChoices[index] || "none";
    }
    AppGroup {
        title: "Shell Appearance"
        icon: "palette"
        badge: "VEYRA"

        SettingSpinBox {
            label: "Shell Background Opacity"
            description: "Adjust the transparency of Veyra panels, popups and shell surfaces. Lower values reveal more of your wallpaper."
            from: 30
            to: 100
            stepSize: 5
            value: Math.round(SettingsService.shellBackgroundOpacity * 100)
            defaultValue: 85
            suffix: "%"
            onMoved: (value) => SettingsService.shellBackgroundOpacity = Math.max(0.3, Math.min(1, Math.round(value) / 100))
        }

        SettingToggle {
            label: "UI Sound Effects"
            description: "Play subtle audio cues on screenshot, recording, charger plug/unplug, lock/unlock, and focus timer completion."
            onToggled: (value) => SettingsService.uiSoundsEnabled = value
            Binding on checked { value: SettingsService.uiSoundsEnabled }
        }
    }

    AppGroup {
        title: "Bar Style"
        icon: "bar"

        SettingSegmented {
            label: "Style"
            description: "Choose between Convex or Island"
            model: [{
                "text": "Convex",
                "value": "convex"
            }, {
                "text": "Island",
                "value": "island"
            }]
            currentValue: SettingsService.barStyle
            onActivated: (value) => {
                SettingsService.barStyle = value;
            }
        }

    }

    AppGroup {
        title: "Bar Widgets"
        icon: "widgets"
        showReset: true

        ThemedSelect {
            label: "Left Slot 1"
            description: "First widget in the left group. In Island mode the left slots only appear while the bar is expanded."
            model: barSettingsRoot.widgetChoices
            textMap: barSettingsRoot.widgetNames
            currentIndex: barSettingsRoot.widgetIndex(SettingsService.barSlotL1)
            defaultIndex: 1
            onActivated: (index) => SettingsService.barSlotL1 = barSettingsRoot.widgetAt(index)
        }

        ThemedSelect {
            label: "Left Slot 2"
            description: "Second widget in the left group."
            model: barSettingsRoot.widgetChoices
            textMap: barSettingsRoot.widgetNames
            currentIndex: barSettingsRoot.widgetIndex(SettingsService.barSlotL2)
            defaultIndex: 0
            onActivated: (index) => SettingsService.barSlotL2 = barSettingsRoot.widgetAt(index)
        }

        ThemedSelect {
            label: "Left Slot 3"
            description: "Third widget in the left group."
            model: barSettingsRoot.widgetChoices
            textMap: barSettingsRoot.widgetNames
            currentIndex: barSettingsRoot.widgetIndex(SettingsService.barSlotL3)
            defaultIndex: 0
            onActivated: (index) => SettingsService.barSlotL3 = barSettingsRoot.widgetAt(index)
        }

        ThemedSelect {
            label: "Center Slot 1"
            description: "Primary center widget. In Convex mode this sits inside the notch."
            model: barSettingsRoot.widgetChoices
            textMap: barSettingsRoot.widgetNames
            currentIndex: barSettingsRoot.widgetIndex(SettingsService.barSlotC1)
            defaultIndex: 3
            onActivated: (index) => SettingsService.barSlotC1 = barSettingsRoot.widgetAt(index)
        }

        ThemedSelect {
            label: "Center Slot 2"
            description: "Secondary center widget, separated by a divider when both are visible."
            model: barSettingsRoot.widgetChoices
            textMap: barSettingsRoot.widgetNames
            currentIndex: barSettingsRoot.widgetIndex(SettingsService.barSlotC2)
            defaultIndex: 2
            onActivated: (index) => SettingsService.barSlotC2 = barSettingsRoot.widgetAt(index)
        }

        ThemedSelect {
            label: "Right Slot 1"
            description: "Widget shown before the right status capsule."
            model: barSettingsRoot.widgetChoices
            textMap: barSettingsRoot.widgetNames
            currentIndex: barSettingsRoot.widgetIndex(SettingsService.barSlotR1)
            defaultIndex: 6
            onActivated: (index) => SettingsService.barSlotR1 = barSettingsRoot.widgetAt(index)
        }

        ThemedSelect {
            label: "Right Slot 2"
            description: "First widget inside the right status capsule. The notification bell always follows it."
            model: barSettingsRoot.widgetChoices
            textMap: barSettingsRoot.widgetNames
            currentIndex: barSettingsRoot.widgetIndex(SettingsService.barSlotR2)
            defaultIndex: 5
            onActivated: (index) => SettingsService.barSlotR2 = barSettingsRoot.widgetAt(index)
        }

        ThemedSelect {
            label: "Right Slot 3"
            description: "Last widget inside the right status capsule."
            model: barSettingsRoot.widgetChoices
            textMap: barSettingsRoot.widgetNames
            currentIndex: barSettingsRoot.widgetIndex(SettingsService.barSlotR3)
            defaultIndex: 4
            onActivated: (index) => SettingsService.barSlotR3 = barSettingsRoot.widgetAt(index)
        }
    }

    AppGroup {
        title: "Convex Bar Shape"
        icon: "sliders"
        badge: "LIVE"
        showReset: true
        visible: SettingsService.barConvexMode

        SettingSpinBox {
            label: "Bar Height"
            description: "Height of the bar band. The center notch grows past it when opened."
            from: 28
            to: 56
            stepSize: 2
            value: SettingsService.convexBarHeight
            defaultValue: 40
            suffix: "px"
            onMoved: (value) => SettingsService.convexBarHeight = Math.max(28, Math.min(56, Math.round(value)))
        }

        SettingSpinBox {
            label: "Top Inset"
            description: "Gap between the screen's top edge and the bar. Keep at 0 for a bar that touches the edge; anything higher floats it and exposes the wallpaper above."
            from: 0
            to: 12
            stepSize: 1
            value: SettingsService.convexTopInset
            defaultValue: 0
            suffix: "px"
            onMoved: (value) => SettingsService.convexTopInset = Math.max(0, Math.min(12, Math.round(value)))
        }

        SettingSpinBox {
            label: "Notch Corner Radius"
            description: "Round the bottom corners of the left, center and right notches."
            from: 0
            to: 24
            stepSize: 2
            value: SettingsService.convexCornerRadius
            defaultValue: 16
            suffix: "px"
            onMoved: (value) => SettingsService.convexCornerRadius = Math.max(0, Math.min(24, Math.round(value)))
        }

        SettingSpinBox {
            label: "Notch Flare"
            description: "Width of the curved shoulders that blend each notch into the bar. 0 gives hard vertical edges."
            from: 0
            to: 32
            stepSize: 2
            value: SettingsService.convexNotchFlare
            defaultValue: 18
            suffix: "px"
            onMoved: (value) => SettingsService.convexNotchFlare = Math.max(0, Math.min(32, Math.round(value)))
        }
    }

    AppGroup {
        title: "Convex Bar Surface"
        icon: "palette"
        showReset: true
        visible: SettingsService.barConvexMode

        SettingToggle {
            label: "Backdrop Blur"
            description: "Let Hyprland blur show through the bar. Turn off to use a fully opaque surface."
            checked: SettingsService.convexBackdropBlur
            defaultValue: true
            onToggled: (checked) => SettingsService.convexBackdropBlur = checked
        }

        SettingSpinBox {
            label: "Background Opacity"
            description: "How much of the wallpaper shows through the bar and its notches."
            enabled: SettingsService.convexBackdropBlur
            from: 30
            to: 100
            stepSize: 5
            value: Math.round(SettingsService.convexBackgroundOpacity * 100)
            defaultValue: 85
            suffix: "%"
            onMoved: (value) => SettingsService.convexBackgroundOpacity = Math.max(0.3, Math.min(1, Math.round(value) / 100))
        }

        SettingToggle {
            label: "Accent Border"
            description: "Outline the whole bar silhouette, including the notch shoulders."
            checked: SettingsService.convexBorderEnabled
            defaultValue: false
            onToggled: (checked) => SettingsService.convexBorderEnabled = checked
        }

        SettingSpinBox {
            label: "Border Width"
            description: "Outline thickness."
            enabled: SettingsService.convexBorderEnabled
            from: 0.5
            to: 3
            stepSize: 0.5
            decimals: 1
            value: SettingsService.convexBorderWidth
            defaultValue: 1
            suffix: "px"
            onMoved: (value) => SettingsService.convexBorderWidth = Math.max(0.5, Math.min(3, value))
        }

        SettingSegmented {
            label: "Border Color"
            description: "Use a rotating two-color accent gradient, a single accent, or a quieter border tone."
            model: [{ "text": "Gradient", "value": "gradient" }, { "text": "Accent", "value": "accent" }, { "text": "Subtle", "value": "subtle" }]
            currentValue: SettingsService.convexBorderColorMode
            defaultValue: "gradient"
            onActivated: (value) => SettingsService.convexBorderColorMode = value
            enabled: SettingsService.convexBorderEnabled
        }

        SettingToggle {
            label: "Bar Shadow"
            description: "Draw the bar's drop shadow over the wallpaper."
            checked: SettingsService.convexShadowEnabled
            defaultValue: true
            onToggled: (checked) => SettingsService.convexShadowEnabled = checked
        }
    }

    AppGroup {
        title: "Convex Screen Frame"
        icon: "monitor"
        showReset: true
        visible: SettingsService.barConvexMode

        SettingToggle {
            label: "Frame Bezel"
            description: "Draw the thin frame around the edge of the screen that the bar sits on."
            checked: SettingsService.convexFrameEnabled
            defaultValue: true
            onToggled: (checked) => SettingsService.convexFrameEnabled = checked
        }

        SettingSpinBox {
            label: "Frame Thickness"
            description: "How thick the frame is along the left, right and bottom edges."
            enabled: SettingsService.convexFrameEnabled
            from: 0
            to: 16
            stepSize: 1
            value: SettingsService.convexFrameSize
            defaultValue: 8
            suffix: "px"
            onMoved: (value) => SettingsService.convexFrameSize = Math.max(0, Math.min(16, Math.round(value)))
        }
    }

    AppGroup {
        title: "Bar Media Visualizer"
        icon: "music"

        SettingToggle {
            label: "Enable Capsule Visualizer"
            description: "Show compact audio bars inside the Island media capsule and Convex media button. Independent of the desktop visualizer overlay."
            checked: SettingsService.barMediaVisualizerEnabled
            onToggled: (checked) => {
                SettingsService.barMediaVisualizerEnabled = checked;
            }
        }
    }

    AppGroup {
        title: "Island Spacing & Shape"
        showReset: true
        icon: "sliders"
        visible: SettingsService.barIslandMode

        SettingSpinBox {
            label: "Capsule Spacing"
            description: "Horizontal gap between the left, center and right capsules."
            from: 4
            to: 24
            stepSize: 2
            value: SettingsService.islandGap
            defaultValue: 10
            suffix: "px"
            onMoved: (value) => SettingsService.islandGap = Math.max(4, Math.min(24, Math.round(value)))
        }

        SettingSpinBox {
            label: "Corner Radius"
            description: "Round the idle capsules. The radius is capped to half of each capsule's height."
            from: 8
            to: 24
            stepSize: 2
            value: SettingsService.islandCornerRadius
            defaultValue: 16
            suffix: "px"
            onMoved: (value) => SettingsService.islandCornerRadius = Math.max(8, Math.min(24, Math.round(value)))
        }
    }

    AppGroup {
        title: "Left Capsule Size"
        showReset: true
        icon: "monitor"
        badge: "INDEPENDENT"
        visible: SettingsService.barIslandMode

        SettingSpinBox {
            label: "Width"
            description: "Scale the left capsule's natural content width."
            from: 70
            to: 160
            stepSize: 5
            value: SettingsService.islandLeftWidthScale
            defaultValue: 100
            suffix: "%"
            onMoved: (value) => SettingsService.islandLeftWidthScale = Math.max(70, Math.min(160, Math.round(value)))
        }

        SettingSpinBox {
            label: "Height"
            description: "Set the left capsule's height independently."
            from: 24
            to: 56
            stepSize: 2
            value: SettingsService.islandLeftHeight
            defaultValue: 32
            suffix: "px"
            onMoved: (value) => SettingsService.islandLeftHeight = Math.max(24, Math.min(56, Math.round(value)))
        }
    }

    AppGroup {
        title: "Center Capsule Size"
        showReset: true
        icon: "clock"
        badge: "INDEPENDENT"
        visible: SettingsService.barIslandMode

        SettingSpinBox {
            label: "Width"
            description: "Scale the center capsule around its current clock or workspace content."
            from: 70
            to: 160
            stepSize: 5
            value: SettingsService.islandCenterWidthScale
            defaultValue: 100
            suffix: "%"
            onMoved: (value) => SettingsService.islandCenterWidthScale = Math.max(70, Math.min(160, Math.round(value)))
        }

        SettingSpinBox {
            label: "Height"
            description: "Set the center capsule's height independently."
            from: 24
            to: 56
            stepSize: 2
            value: SettingsService.islandCenterHeight
            defaultValue: 32
            suffix: "px"
            onMoved: (value) => SettingsService.islandCenterHeight = Math.max(24, Math.min(56, Math.round(value)))
        }
    }

    AppGroup {
        title: "Right Capsule Size"
        showReset: true
        icon: "music"
        badge: "INDEPENDENT"
        visible: SettingsService.barIslandMode

        SettingSpinBox {
            label: "Width"
            description: "Scale the right capsule for the music or Control Center indicator."
            from: 70
            to: 160
            stepSize: 5
            value: SettingsService.islandRightWidthScale
            defaultValue: 100
            suffix: "%"
            onMoved: (value) => SettingsService.islandRightWidthScale = Math.max(70, Math.min(160, Math.round(value)))
        }

        SettingSpinBox {
            label: "Height"
            description: "Set the right capsule's height independently."
            from: 24
            to: 56
            stepSize: 2
            value: SettingsService.islandRightHeight
            defaultValue: 32
            suffix: "px"
            onMoved: (value) => SettingsService.islandRightHeight = Math.max(24, Math.min(56, Math.round(value)))
        }
    }

    AppGroup {
        title: "Island Appearance"
        showReset: true
        icon: "palette"
        badge: "LIVE"
        visible: SettingsService.barIslandMode

        SettingToggle {
            label: "Backdrop Blur"
            description: "Let Hyprland blur show through the Island's translucent surface. Turn off to use an opaque background."
            checked: SettingsService.islandBackdropBlur
            defaultValue: true
            onToggled: (checked) => SettingsService.islandBackdropBlur = checked
        }

        SettingSpinBox {
            label: "Background Opacity"
            description: "Control how much of the wallpaper shows through the Island."
            enabled: SettingsService.islandBackdropBlur
            from: 30
            to: 100
            stepSize: 5
            value: Math.round(SettingsService.islandBackgroundOpacity * 100)
            defaultValue: 85
            suffix: "%"
            onMoved: (value) => SettingsService.islandBackgroundOpacity = Math.max(0.3, Math.min(1, Math.round(value) / 100))
        }

        SettingToggle {
            label: "Accent Border"
            description: "Draw a fine outline around the Island using your dynamic wallpaper accent."
            checked: SettingsService.islandBorderEnabled
            defaultValue: false
            onToggled: (checked) => SettingsService.islandBorderEnabled = checked
        }

        SettingSpinBox {
            label: "Border Width"
            description: "Set the outline thickness."
            enabled: SettingsService.islandBorderEnabled
            from: 0.5
            to: 3
            stepSize: 0.5
            decimals: 1
            value: SettingsService.islandBorderWidth
            defaultValue: 1
            suffix: "px"
            onMoved: (value) => SettingsService.islandBorderWidth = Math.max(0.5, Math.min(3, value))
        }

        SettingSegmented {
            label: "Border Color"
            description: "Use a rotating two-color accent gradient, a single accent, or a quieter theme border."
            model: [{ "text": "Gradient", "value": "gradient" }, { "text": "Accent", "value": "accent" }, { "text": "Subtle", "value": "subtle" }]
            currentValue: SettingsService.islandBorderColorMode
            defaultValue: "gradient"
            onActivated: (value) => SettingsService.islandBorderColorMode = value
            enabled: SettingsService.islandBorderEnabled
        }

        SettingToggle {
            label: "Island Shadow"
            description: "Show a soft shadow below the capsules and expanded Island panel."
            checked: SettingsService.islandShadowEnabled
            defaultValue: true
            onToggled: (checked) => SettingsService.islandShadowEnabled = checked
        }

        SettingSpinBox {
            label: "Shadow Strength"
            description: "Adjust the shadow opacity."
            enabled: SettingsService.islandShadowEnabled
            from: 0
            to: 100
            stepSize: 5
            value: SettingsService.islandShadowStrength
            defaultValue: 65
            suffix: "%"
            onMoved: (value) => SettingsService.islandShadowStrength = Math.max(0, Math.min(100, Math.round(value)))
        }
    }

    // These controls map directly to the three visible idle capsules.
    AppGroup {
        title: "Island Layout"
        showReset: true
        icon: "widgets"
        badge: "LIVE"
        visible: SettingsService.barIslandMode

        SettingSegmented {
            label: "Left Capsule"
            description: "Choose the compact widget shown on the left side of the Island."
            model: [{
                "text": "System Monitor",
                "value": "sysmon"
            }, {
                "text": "Workspaces",
                "value": "workspaces"
            }]
            currentValue: SettingsService.islandLeftWidget
            defaultValue: "sysmon"
            onActivated: (value) => SettingsService.islandLeftWidget = value
        }

        SettingSegmented {
            label: "Center Capsule"
            description: "Choose what stays visible in the center capsule."
            model: [{
                "text": "Clock",
                "value": "clock"
            }, {
                "text": "Workspaces",
                "value": "workspaces"
            }, {
                "text": "Clock + Preview",
                "value": "clock_workspaces"
            }]
            currentValue: SettingsService.islandCenterWidget
            defaultValue: "clock_workspaces"
            onActivated: (value) => SettingsService.islandCenterWidget = value
        }
    }

    AppGroup {
        title: "Right Capsule"
        showReset: true
        icon: "music"
        visible: SettingsService.barIslandMode

        SettingSegmented {
            label: "Right Circular Island"
            description: "Auto shows album art when media is available and Control Center when idle."
            model: [{
                "text": "Auto",
                "value": "auto"
            }, {
                "text": "Always Music",
                "value": "music"
            }, {
                "text": "Always Control Center",
                "value": "control_center"
            }]
            currentValue: SettingsService.islandRightMode
            defaultValue: "auto"
            onActivated: (value) => SettingsService.islandRightMode = value
        }
    }

    AppGroup {
        title: "System Tray"
        icon: "widgets"

        SettingSegmented {
            label: "Icon Size"
            description: "Make the system tray icons smaller or larger"
            model: [{
                "text": "Small",
                "value": "small"
            }, {
                "text": "Medium",
                "value": "medium"
            }, {
                "text": "Large",
                "value": "large"
            }, {
                "text": "Extra Large",
                "value": "xlarge"
            }]
            currentValue: SettingsService.trayIconSize
            onActivated: (value) => {
                SettingsService.trayIconSize = value;
            }
        }

    }

    AppGroup {
        title: "Clock Format"
        showReset: true
        icon: "clock"

        SettingToggle {
            label: "24-Hour Time"
            description: "Use 24-hour time format instead of 12-hour AM/PM"
            checked: SettingsService.clock24h
            defaultValue: true
            onToggled: (checked) => SettingsService.clock24h = checked
        }

        SettingToggle {
            label: "Show Seconds"
            description: "Display seconds on the main clock"
            checked: SettingsService.clockSeconds
            defaultValue: false
            onToggled: (checked) => SettingsService.clockSeconds = checked
        }

        SettingToggle {
            label: "Show Date"
            description: "Display the current date next to the clock"
            checked: SettingsService.clockShowDate
            defaultValue: true
            onToggled: (checked) => SettingsService.clockShowDate = checked
        }

        SettingToggle {
            label: "Show Weather in Calendar"
            description: "Display current weather and today's high and low"
            checked: SettingsService.clockWeatherEnabled
            defaultValue: false
            onToggled: (checked) => SettingsService.clockWeatherEnabled = checked
        }

        ThemedText {
            visible: SettingsService.clockWeatherEnabled
            text: "Weather location"
            customSize: Constants.sizeSm
            color: Theme.muted
        }

        VeyraTextField {
            id: weatherLocationField
            visible: SettingsService.clockWeatherEnabled
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            text: SettingsService.clockWeatherLocation
            placeholderText: "City, country"
            placeholderTextColor: Theme.muted
            color: Theme.fg
            selectByMouse: true
            font.pixelSize: 12

            function commitLocation() {
                const value = text.trim();
                if (value.length > 0)
                    SettingsService.clockWeatherLocation = value;
                text = SettingsService.clockWeatherLocation;
            }

            onEditingFinished: commitLocation()
            onAccepted: {
                commitLocation();
                focus = false;
            }

            background: Rectangle {
                radius: 8
                color: Theme.bgSecondary
                border.width: weatherLocationField.activeFocus ? 1 : 0
                border.color: Theme.accent
            }
        }

        ThemedText {
            visible: SettingsService.clockWeatherEnabled
            text: "Example: City, Country"
            customSize: Constants.sizeXs
            color: Theme.muted
        }

    }

}
