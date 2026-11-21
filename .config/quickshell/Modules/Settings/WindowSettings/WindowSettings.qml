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

    pageTitle: "Hyprland"
    pageDescription: "One place for layout, window geometry, opacity, blur, shadows, animations and pointer behavior."
    pageIcon: "monitor"

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 76
        radius: Constants.sizeMd
        color: Theme.bgSecondary
        border.width: 1
        border.color: Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Constants.sizeLg
            anchors.rightMargin: Constants.sizeLg
            spacing: Constants.sizeMd

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: Constants.sizeSm
                color: Theme.bgAccent

                SvgIcon {
                    anchors.centerIn: parent
                    icon: "monitor"
                    iconSize: 21
                    iconColor: Theme.accent
                    flat: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Constants.size2Xs

                ThemedText {
                    text: HyprlandService.hyprPrefsLoaded ? "Compositor connected" : "Reading compositor settings…"
                    customSize: Constants.sizeSm + 1
                    font.weight: Font.DemiBold
                    color: Theme.fg
                }

                ThemedText {
                    text: "Current layout: " + (HyprlandService.hyprLayout === "master" ? "Master" : "Dwindle") + "  ·  " + (HyprlandService.enableAnimations ? "Animations enabled" : "Animations disabled")
                    customSize: Constants.sizeXs + 1
                    color: Theme.muted
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 34
                color: Theme.border
            }

            ThemeButton {
                text: "Refresh"
                enabled: HyprlandService.hyprPrefsLoaded
                onClicked: HyprlandService.reloadHyprPrefs()
            }
        }
    }

    AppGroup {
        title: "Layout & Workspace Behavior"
        icon: "layout-filled"
        badge: "LIVE"
        collapsible: true

        SettingSegmented {
            label: "Tiling Layout"
            description: "Choose how new tiled windows are arranged."
            model: [
                { "text": "Dwindle", "value": "dwindle" },
                { "text": "Master", "value": "master" }
            ]
            currentValue: HyprlandService.hyprLayout
            onActivated: (value) => HyprlandService.hyprLayout = value
        }

        SettingToggle {
            id: preserveSplitToggle
            label: "Preserve Split Direction"
            description: "Keep split orientation stable. Smart Split enables this behavior automatically."
            enabled: HyprlandService.hyprLayout === "dwindle" && !HyprlandService.dwindleSmartSplit
            onToggled: (value) => HyprlandService.hyprPreserveSplit = value
            Binding on checked { value: HyprlandService.hyprPreserveSplit }
        }
    }

    AppGroup {
        title: "Dwindle Layout Options"
        icon: "layout-filled"
        badge: "DWINDLE"
        collapsible: true
        visible: HyprlandService.hyprLayout === "dwindle"

        SettingToggle {
            label: "Smart Split"
            description: "Choose split direction using the position of the pointer when opening a window."
            onToggled: (value) => {
                HyprlandService.dwindleSmartSplit = value;
                if (value)
                    HyprlandService.hyprPreserveSplit = true;
            }
            Binding on checked { value: HyprlandService.dwindleSmartSplit }
        }

        SettingToggle {
            label: "Smart Resizing"
            description: "Use the smart resize behavior when adjusting tiled windows."
            onToggled: (value) => HyprlandService.dwindleSmartResizing = value
            Binding on checked { value: HyprlandService.dwindleSmartResizing }
        }

        SettingSegmented {
            label: "New Window Split"
            description: "Choose where a new window is placed relative to the existing split."
            model: [
                { "text": "Pointer", "value": 0 },
                { "text": "Left / Top", "value": 1 },
                { "text": "Right / Bottom", "value": 2 }
            ]
            currentValue: HyprlandService.dwindleForceSplit
            onActivated: (value) => HyprlandService.dwindleForceSplit = value
        }

        SettingSpinBox {
            label: "Default Split Ratio"
            description: "Initial size ratio for a new Dwindle split. 1.0 gives both sides equal space."
            from: 0.1
            to: 1.9
            stepSize: 0.1
            decimals: 1
            value: HyprlandService.dwindleDefaultSplitRatio
            defaultValue: 1.0
            onMoved: (value) => HyprlandService.dwindleDefaultSplitRatio = value
        }

        SettingSpinBox {
            label: "Split Width Multiplier"
            description: "Adjust automatic split widths for wide or ultrawide displays."
            from: 0.1
            to: 3.0
            stepSize: 0.1
            decimals: 1
            value: HyprlandService.dwindleSplitWidthMultiplier
            defaultValue: 1.0
            onMoved: (value) => HyprlandService.dwindleSplitWidthMultiplier = value
        }

        SettingToggle {
            label: "Prefer Focused Window"
            description: "Use the active window as the preferred target when creating splits."
            onToggled: (value) => HyprlandService.dwindleUseActiveForSplits = value
            Binding on checked { value: HyprlandService.dwindleUseActiveForSplits }
        }

        SettingToggle {
            label: "Persistent Direction Override"
            description: "Keep a manually selected split direction active until changed again."
            onToggled: (value) => HyprlandService.dwindlePermanentDirectionOverride = value
            Binding on checked { value: HyprlandService.dwindlePermanentDirectionOverride }
        }

        SettingSegmented {
            label: "Split Ratio Target"
            description: "Choose which side receives the new split ratio."
            model: [
                { "text": "Directional", "value": 0 },
                { "text": "Focused", "value": 1 }
            ]
            currentValue: HyprlandService.dwindleSplitBias
            onActivated: (value) => HyprlandService.dwindleSplitBias = value
        }

        SettingToggle {
            label: "Precise Window Dragging"
            description: "Place dragged windows more precisely based on the pointer position."
            onToggled: (value) => HyprlandService.dwindlePreciseMouseMove = value
            Binding on checked { value: HyprlandService.dwindlePreciseMouseMove }
        }
    }

    AppGroup {
        title: "Master Layout Options"
        icon: "layout-filled"
        badge: "MASTER"
        collapsible: true
        visible: HyprlandService.hyprLayout === "master"

        SettingSegmented {
            label: "Master Position"
            description: "Place the master area on the selected side of the screen."
            model: [
                { "text": "Left", "value": "left" },
                { "text": "Right", "value": "right" },
                { "text": "Top", "value": "top" },
                { "text": "Bottom", "value": "bottom" },
                { "text": "Center", "value": "center" }
            ]
            currentValue: HyprlandService.masterOrientation
            onActivated: (value) => HyprlandService.masterOrientation = value
        }

        SettingSpinBox {
            label: "Master Area Size"
            description: "Set the master area's share of the available space."
            from: 10
            to: 90
            stepSize: 5
            value: Math.round(HyprlandService.masterMfact * 100)
            defaultValue: 55
            suffix: "%"
            onMoved: (value) => HyprlandService.masterMfact = value / 100
        }

        SettingSegmented {
            label: "New Window Placement"
            description: "Choose whether new windows join the master or stack area."
            model: [
                { "text": "Master", "value": "master" },
                { "text": "Stack", "value": "slave" },
                { "text": "Inherit", "value": "inherit" }
            ]
            currentValue: HyprlandService.masterNewStatus
            onActivated: (value) => HyprlandService.masterNewStatus = value
        }

        SettingToggle {
            label: "Allow Small Splits"
            description: "Allow the master layout to create smaller splits when space is limited."
            onToggled: (value) => HyprlandService.masterAllowSmallSplit = value
            Binding on checked { value: HyprlandService.masterAllowSmallSplit }
        }

        SettingToggle {
            label: "Smart Resizing"
            description: "Use the pointer position to determine the direction of resize operations."
            onToggled: (value) => HyprlandService.masterSmartResizing = value
            Binding on checked { value: HyprlandService.masterSmartResizing }
        }

        SettingToggle {
            label: "New Windows on Top"
            description: "Place new stack windows at the top of the stack."
            onToggled: (value) => HyprlandService.masterNewOnTop = value
            Binding on checked { value: HyprlandService.masterNewOnTop }
        }

        SettingSegmented {
            label: "Place New Windows"
            description: "Choose where a new window is inserted relative to the focused window."
            model: [
                { "text": "Default", "value": "none" },
                { "text": "Before", "value": "before" },
                { "text": "After", "value": "after" }
            ]
            currentValue: HyprlandService.masterNewOnActive
            onActivated: (value) => HyprlandService.masterNewOnActive = value
        }

        SettingToggle {
            label: "Drop Windows at Cursor"
            description: "Place dragged windows at the pointer position when dropping them."
            onToggled: (value) => HyprlandService.masterDropAtCursor = value
            Binding on checked { value: HyprlandService.masterDropAtCursor }
        }

        SettingToggle {
            label: "Keep Master Position"
            description: "Keep the master window in its configured position when no stack windows remain."
            onToggled: (value) => HyprlandService.masterAlwaysKeepPosition = value
            Binding on checked { value: HyprlandService.masterAlwaysKeepPosition }
        }

        SettingToggle {
            label: "Focus Master on Close"
            description: "Return focus to the master window when another window closes."
            onToggled: (value) => HyprlandService.masterFocusMasterOnClose = value
            Binding on checked { value: HyprlandService.masterFocusMasterOnClose }
        }

        SettingSpinBox {
            label: "Center Master Threshold"
            description: "Number of stack windows required before the centered master layout activates. Set to 0 to always center."
            visible: HyprlandService.masterOrientation === "center"
            from: 0
            to: 10
            stepSize: 1
            value: HyprlandService.masterSlaveCountForCenter
            defaultValue: 2
            onMoved: (value) => HyprlandService.masterSlaveCountForCenter = Math.round(value)
        }

        SettingSegmented {
            label: "Center Fallback"
            description: "Choose where the master area moves when the center threshold is not met."
            visible: HyprlandService.masterOrientation === "center"
            model: [
                { "text": "Left", "value": "left" },
                { "text": "Right", "value": "right" },
                { "text": "Top", "value": "top" },
                { "text": "Bottom", "value": "bottom" }
            ]
            currentValue: HyprlandService.masterCenterFallback
            onActivated: (value) => HyprlandService.masterCenterFallback = value
        }
    }

    AppGroup {
        title: "Window Geometry"
        icon: "window"
        collapsible: true

        SettingSpinBox {
            label: "Inner Gaps"
            description: "Space between tiled windows."
            from: 0
            to: 30
            stepSize: 1
            value: HyprlandService.hyprGapsIn
            defaultValue: 4
            suffix: "px"
            onMoved: (value) => HyprlandService.hyprGapsIn = Math.round(value)
        }

        SettingSpinBox {
            label: "Outer Gaps"
            description: "Space between windows and the screen edge."
            from: 0
            to: 60
            stepSize: 1
            value: HyprlandService.hyprGapsOut
            defaultValue: 8
            suffix: "px"
            onMoved: (value) => HyprlandService.hyprGapsOut = Math.round(value)
        }

        SettingSpinBox {
            label: "Border Thickness"
            description: "Set the active and inactive window border width."
            from: 0
            to: 10
            stepSize: 1
            value: HyprlandService.hyprBorderSize
            defaultValue: 2
            suffix: "px"
            onMoved: (value) => HyprlandService.hyprBorderSize = Math.round(value)
        }

        SettingSpinBox {
            label: "Corner Rounding"
            description: "Round the corners of application windows."
            from: 0
            to: 40
            stepSize: 1
            value: HyprlandService.hyprRounding
            defaultValue: 16
            suffix: "px"
            onMoved: (value) => HyprlandService.hyprRounding = Math.round(value)
        }
    }

    AppGroup {
        title: "Window Opacity"
        icon: "eye-off"
        collapsible: true

        SettingSpinBox {
            label: "Focused Window"
            description: "Opacity of the currently focused application."
            from: 20
            to: 100
            stepSize: 5
            value: HyprlandService.hyprActiveOpacity
            defaultValue: 100
            suffix: "%"
            onMoved: (value) => HyprlandService.hyprActiveOpacity = Math.round(value)
        }

        SettingSpinBox {
            label: "Unfocused Windows"
            description: "Opacity applied to windows that are not focused."
            from: 20
            to: 100
            stepSize: 5
            value: HyprlandService.hyprInactiveOpacity
            defaultValue: 100
            suffix: "%"
            onMoved: (value) => HyprlandService.hyprInactiveOpacity = Math.round(value)
        }
    }

    AppGroup {
        title: "Blur, Transparency & Shaders"
        icon: "window"
        collapsible: true

        SettingToggle {
            id: blurToggle
            label: "Enable Window Blur"
            description: "Use background blur for translucent windows and shell surfaces."
            onToggled: (value) => HyprlandService.hyprBlur = value
            Binding on checked { value: HyprlandService.hyprBlur }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd
            enabled: HyprlandService.hyprBlur
            opacity: enabled ? 1 : 0.48

            SettingSpinBox {
                label: "Blur Size"
                description: "Higher values produce a softer, more diffuse blur."
                from: 1
                to: 20
                stepSize: 1
                value: HyprlandService.hyprBlurSize
                defaultValue: 6
                onMoved: (value) => HyprlandService.hyprBlurSize = Math.round(value)
            }

            SettingSpinBox {
                label: "Blur Passes"
                description: "More passes improve smoothness at a higher GPU cost."
                from: 1
                to: 10
                stepSize: 1
                value: HyprlandService.hyprBlurPasses
                defaultValue: 4
                onMoved: (value) => HyprlandService.hyprBlurPasses = Math.round(value)
            }
        }

        SettingSegmented {
            label: "Screen Shader"
            description: "Apply a real-time GLSL screen effect (cycle anytime with SUPER+ALT+H)."
            model: [
                { "text": "Off", "value": "none" },
                { "text": "Vibrance", "value": "vibrance" },
                { "text": "Film Grain", "value": "film-grain" },
                { "text": "CRT", "value": "crt" },
                { "text": "Warm", "value": "warm" }
            ]
            currentValue: SettingsService.hyprScreenShader
            onActivated: (value) => SettingsService.hyprScreenShader = value
        }
    }

    AppGroup {
        title: "Shadows & Accent Glow"
        icon: "sun"
        collapsible: true

        SettingToggle {
            id: shadowToggle
            label: "Enable Window Shadows"
            description: "Add depth around floating and tiled windows."
            onToggled: (value) => HyprlandService.hyprShadow = value
            Binding on checked { value: HyprlandService.hyprShadow }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd
            enabled: HyprlandService.hyprShadow
            opacity: enabled ? 1 : 0.48

            SettingToggle {
                label: "Accent Window Glow"
                description: "Tint the focused window's shadow with your wallpaper palette instead of a dark shadow."
                onToggled: (value) => SettingsService.shadowGlowEnabled = value
                Binding on checked { value: SettingsService.shadowGlowEnabled }
            }

            SettingSegmented {
                label: "Glow Color"
                description: "Choose which palette accent colors the active window glow."
                visible: SettingsService.shadowGlowEnabled
                model: [
                    { "text": "Primary Accent", "value": "accent" },
                    { "text": "Secondary Accent", "value": "complementary" }
                ]
                currentValue: SettingsService.shadowGlowMode
                onActivated: (value) => SettingsService.shadowGlowMode = value
            }

            SettingSpinBox {
                label: "Glow Intensity"
                description: "Opacity of the focused window's accent glow."
                visible: SettingsService.shadowGlowEnabled
                from: 10
                to: 100
                stepSize: 5
                value: SettingsService.shadowGlowOpacity
                defaultValue: 80
                suffix: "%"
                onMoved: (value) => SettingsService.shadowGlowOpacity = Math.round(value)
            }

            SettingSpinBox {
                label: "Glow & Shadow Range"
                description: "Controls how far the window shadow or accent glow extends."
                from: 1
                to: 60
                stepSize: 1
                value: HyprlandService.hyprShadowRange
                defaultValue: 14
                suffix: "px"
                onMoved: (value) => HyprlandService.hyprShadowRange = Math.round(value)
            }

            SettingSpinBox {
                label: "Glow Falloff (Render Power)"
                description: "Lower values create a wider, softer halo; higher values tighten the glow near the border."
                from: 1
                to: 4
                stepSize: 1
                value: HyprlandService.hyprShadowRenderPower
                defaultValue: 3
                onMoved: (value) => HyprlandService.hyprShadowRenderPower = Math.round(value)
            }
        }
    }

    AppGroup {
        title: "Animation & Motion"
        icon: "sparkles"
        collapsible: true

        SettingToggle {
            id: animationsToggle
            label: "Enable Hyprland Animations"
            description: "Turn compositor window, workspace and fade animations on or off."
            onToggled: (value) => HyprlandService.enableAnimations = value
            Binding on checked { value: HyprlandService.enableAnimations }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd
            enabled: HyprlandService.enableAnimations
            opacity: enabled ? 1 : 0.48

            SettingSpinBox {
                label: "Animation Speed"
                description: "Controls Veyra's interface transition timing alongside Hyprland's animation preference."
                from: 0
                to: 2
                stepSize: 0.1
                decimals: 1
                value: HyprlandService.enableAnimations ? HyprlandService.animationSpeedFactor : 0
                suffix: "x"
                allowOff: true
                offText: "Off"
                onMoved: (value) => {
                    if (value <= 0.001) {
                        HyprlandService.enableAnimations = false;
                    } else {
                        HyprlandService.animationSpeedFactor = Number(value.toFixed(1));
                        if (!HyprlandService.enableAnimations)
                            HyprlandService.enableAnimations = true;
                    }
                }
            }

            SettingSegmented {
                label: "Animation Curve (Feel)"
                description: "Choose the motion easing curve for windows and workspaces."
                model: [
                    { "text": "Overshot", "value": "overshot" },
                    { "text": "Spring", "value": "spring" },
                    { "text": "Smooth", "value": "ease" },
                    { "text": "Snappy", "value": "snappy" }
                ]
                currentValue: SettingsService.hyprAnimCurve
                onActivated: (value) => SettingsService.hyprAnimCurve = value
            }

            SettingSegmented {
                label: "Window Open & Close Style"
                description: "Choose how windows appear and disappear."
                model: [
                    { "text": "Pop-in 80%", "value": "popin 80%" },
                    { "text": "Deep Zoom", "value": "popin 60%" },
                    { "text": "Slide", "value": "slide" },
                    { "text": "Gnomed", "value": "gnomed" }
                ]
                currentValue: SettingsService.hyprAnimWindowStyle
                onActivated: (value) => SettingsService.hyprAnimWindowStyle = value
            }

            SettingSegmented {
                label: "Workspace Switch Style"
                description: "Choose how workspaces transition when switching."
                model: [
                    { "text": "Slide", "value": "slide" },
                    { "text": "Vertical", "value": "slidevert" },
                    { "text": "Slide + Fade", "value": "slidefade 20%" },
                    { "text": "Fade", "value": "fade" }
                ]
                currentValue: SettingsService.hyprAnimWorkspaceStyle
                onActivated: (value) => SettingsService.hyprAnimWorkspaceStyle = value
            }

            SettingToggle {
                label: "Rotating Gradient Border"
                description: "Continuously rotate the active window's accent gradient border."
                onToggled: (value) => SettingsService.hyprAnimBorderSpin = value
                Binding on checked { value: SettingsService.hyprAnimBorderSpin }
            }

            SettingSpinBox {
                label: "Border Spin Duration"
                description: "Lower values spin the gradient border faster; higher values slow it down."
                visible: SettingsService.hyprAnimBorderSpin
                from: 15
                to: 120
                stepSize: 5
                value: SettingsService.hyprAnimBorderSpeed
                defaultValue: 60
                onMoved: (value) => SettingsService.hyprAnimBorderSpeed = Math.round(value)
            }

            SettingToggle {
                label: "Shell & Layer Pop-in"
                description: "Animate bars, menus, and overlay popups with pop-in and fade."
                onToggled: (value) => SettingsService.hyprAnimLayers = value
                Binding on checked { value: SettingsService.hyprAnimLayers }
            }
        }

        ThemedText {
            Layout.fillWidth: true
            text: "Power Saver and Game Mode may temporarily reduce motion."
            customSize: Constants.sizeXs + 1
            color: Theme.muted
            wrapMode: Text.WordWrap
        }
    }

    AppGroup {
        title: "Pointer & Focus Behavior"
        icon: "cursor-filled"
        collapsible: true

        SettingToggle {
            id: focusFollowsPointerToggle
            label: "Focus Follows Pointer"
            description: "Move keyboard focus to the window under the pointer."
            onToggled: (value) => HyprlandService.mouseFollowMouse = value ? 1 : 0
            Binding on checked { value: HyprlandService.mouseFollowMouse !== 0 }
        }

        SettingSpinBox {
            label: "Cursor Inactive Timeout"
            description: "Hide the pointer after it has been idle. Set to Off to disable."
            from: 0
            to: 60
            stepSize: 1
            value: HyprlandService.cursorInactiveTimeout
            defaultValue: 5
            suffix: "s"
            allowOff: true
            offText: "Off"
            onMoved: (value) => HyprlandService.cursorInactiveTimeout = Math.round(value)
        }

        SettingToggle {
            id: preventCursorWarpsToggle
            label: "Prevent Cursor Warps"
            description: "Stop automatic pointer movement when focus changes."
            onToggled: (value) => HyprlandService.cursorNoWarps = value
            Binding on checked { value: HyprlandService.cursorNoWarps }
        }
    }
}
