import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Core.Services

PanelWindow {
    id: root

    property bool gameMode: false

    visible: SettingsService.settingsLoaded
        && SettingsService.desktopCavaEnabled
        && !gameMode
        && MprisService.isPlaying
        && SystemInfoService.effectivePowerProfile !== "power-saver"

    surfaceFormat.opaque: false
    color: "transparent"
    focusable: false
    implicitHeight: SettingsService.desktopCavaHeight

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        bottom: true
        left: true
        right: true
    }

    // Draw the visualizer without intercepting desktop clicks.
    mask: Region {}

    Item {
        anchors.fill: parent

        Row {
            id: bars

            anchors.centerIn: parent
            width: Math.min(Math.max(1, parent.width - 24), SettingsService.desktopCavaWidth)
            height: Math.max(20, SettingsService.desktopCavaHeight - 20)
            spacing: Math.min(
                SettingsService.desktopCavaSpacing,
                Math.max(0, (bars.width - SettingsService.desktopCavaBarCount * 2)
                    / Math.max(1, SettingsService.desktopCavaBarCount - 1))
            )

            Repeater {
                model: SettingsService.desktopCavaBarCount

                delegate: Item {
                    required property int index

                    width: (bars.width - bars.spacing * (SettingsService.desktopCavaBarCount - 1)) / SettingsService.desktopCavaBarCount
                    height: bars.height

                    Rectangle {
                        anchors.centerIn: parent

                        width: Math.min(6, parent.width * 0.6)
                        radius: width / 2
                        opacity: 0.9

                        height: {
                            const values = CavaService.cavaData;
                            if (!MprisService.isPlaying || !values
                                    || values.length === 0)
                                return 3;

                            const sample = Math.floor(
                                index * values.length
                                / Math.max(1, SettingsService.desktopCavaBarCount)
                            );
                            const value = Number(
                                values[Math.min(values.length - 1, sample)]
                            ) || 0;

                            const maxBarHeight = Math.max(3, bars.height - 4);
                            return Math.max(3, Math.min(
                                maxBarHeight,
                                3 + (value / 100) * (maxBarHeight - 3)
                            ));
                        }

                        color: {
                            if (SettingsService.desktopCavaColorMode === "accent")
                                return Theme.accent;
                            if (SettingsService.desktopCavaColorMode === "complementary")
                                return Theme.accentComplementary;

                            const t = index / Math.max(1, SettingsService.desktopCavaBarCount - 1);
                            return Qt.rgba(
                                Theme.accent.r * (1 - t)
                                    + Theme.accentComplementary.r * t,
                                Theme.accent.g * (1 - t)
                                    + Theme.accentComplementary.g * t,
                                Theme.accent.b * (1 - t)
                                    + Theme.accentComplementary.b * t,
                                Theme.accent.a * (1 - t)
                                    + Theme.accentComplementary.a * t
                            );
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: 90
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                }
            }
        }
    }
}
