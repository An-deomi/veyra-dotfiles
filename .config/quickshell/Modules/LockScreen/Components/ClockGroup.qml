import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Components

ColumnLayout {
    id: root

    readonly property var activePlayer: MprisService.activePlayer
    readonly property bool hasMedia: activePlayer !== null && (((activePlayer.trackTitle || "").trim() !== "") || ((activePlayer.trackArtist || "").trim() !== ""))
    readonly property string clockStyle: SettingsService.lockScreenClockStyle
    readonly property bool isStackedClock: SettingsService.lockScreenClockLayout === "stacked"
    readonly property int clockFontWeight: SettingsService.lockScreenClockWeight === "thin" ? Font.Light : (SettingsService.lockScreenClockWeight === "regular" ? Font.Normal : Font.DemiBold)
    readonly property int mainClockSize: clockStyle === "compact" ? 64 : (clockStyle === "minimal" ? 48 : 84)
    readonly property int secondsClockSize: clockStyle === "compact" ? 32 : (clockStyle === "minimal" ? 24 : 42)
    readonly property color contrastText: SettingsService.lockScreenAdaptiveContrast
        ? (Theme.wallpaperIsDark ? "#F7F8FC" : "#171923") : Theme.fg
    readonly property color contrastMuted: SettingsService.lockScreenAdaptiveContrast
        ? (Theme.wallpaperIsDark ? "#CED2DA" : "#454955") : Theme.muted

    spacing: clockStyle === "minimal" ? Constants.sizeSm : Constants.sizeMd

    // Main Clock Display with contrast styling and settings respect
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        visible: SettingsService.lockScreenShowClock && !root.isStackedClock
        spacing: Constants.sizeXs

        ThemedText {
            id: hoursText

            text: {
                let t = SystemInfoService.currentTime;
                if (SettingsService.lockScreen24h)
                    return Qt.formatTime(t, "HH");

                let h = t.getHours() % 12 || 12;
                return h.toString().padStart(2, "0");
            }
            customSize: root.mainClockSize
            font.weight: root.clockFontWeight
            color: root.contrastText
            layer.enabled: true
            layer.effect: LinearGradient {
                start: Qt.point(0, 0)
                end: Qt.point(hoursText.width, hoursText.height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.contrastText }
                    GradientStop { position: 1.0; color: Theme.accent }
                }
            }
        }

        ThemedText {
            id: colonText

            text: ":"
            customSize: root.mainClockSize
            font.weight: Font.Light
            color: Theme.accent
            opacity: colonTimer.colonVisible ? 1 : 0.25

            Timer {
                id: colonTimer

                property bool colonVisible: true

                interval: 1000
                running: true
                repeat: true
                onTriggered: colonVisible = !colonVisible
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Constants.animNormal
                }

            }

        }

        ThemedText {
            id: minutesText

            text: Qt.formatTime(SystemInfoService.currentTime, "mm")
            customSize: root.mainClockSize
            font.weight: root.clockFontWeight
            color: Theme.accent
            layer.enabled: true
            layer.effect: LinearGradient {
                start: Qt.point(0, 0)
                end: Qt.point(minutesText.width, minutesText.height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 1.0; color: Theme.accentComplementary }
                }
            }
        }

        ThemedText {
            visible: SettingsService.lockScreenShowSeconds
            text: Qt.formatTime(SystemInfoService.currentTime, ":ss")
            customSize: root.secondsClockSize
            font.weight: Font.Light
            color: root.contrastMuted
            Layout.alignment: Qt.AlignBaseline
        }

        ThemedText {
            visible: !SettingsService.lockScreen24h
            text: SystemInfoService.currentTime.getHours() >= 12 ? "PM" : "AM"
            customSize: clockStyle === "minimal" ? 14 : (clockStyle === "compact" ? 18 : 22)
            font.weight: Font.Bold
            color: Theme.accent
            Layout.alignment: Qt.AlignBaseline
            Layout.leftMargin: Constants.sizeXs
        }

    }

    // Stacked vertical clock layout preset
    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        visible: SettingsService.lockScreenShowClock && root.isStackedClock
        spacing: -Constants.sizeSm

        ThemedText {
            id: stackedHoursText

            Layout.alignment: Qt.AlignHCenter
            text: {
                let t = SystemInfoService.currentTime;
                if (SettingsService.lockScreen24h)
                    return Qt.formatTime(t, "HH");

                let h = t.getHours() % 12 || 12;
                return h.toString().padStart(2, "0");
            }
            customSize: root.mainClockSize
            font.weight: root.clockFontWeight
            color: root.contrastText
            layer.enabled: true
            layer.effect: LinearGradient {
                start: Qt.point(0, 0)
                end: Qt.point(stackedHoursText.width, stackedHoursText.height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.contrastText }
                    GradientStop { position: 1.0; color: Theme.accent }
                }
            }
        }

        ThemedText {
            id: stackedMinutesText

            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(SystemInfoService.currentTime, "mm")
            customSize: root.mainClockSize
            font.weight: root.clockFontWeight
            color: Theme.accent
            layer.enabled: true
            layer.effect: LinearGradient {
                start: Qt.point(0, 0)
                end: Qt.point(stackedMinutesText.width, stackedMinutesText.height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 1.0; color: Theme.accentComplementary }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Constants.sizeXs
            visible: SettingsService.lockScreenShowSeconds || !SettingsService.lockScreen24h
            spacing: Constants.sizeXs

            ThemedText {
                visible: SettingsService.lockScreenShowSeconds
                text: Qt.formatTime(SystemInfoService.currentTime, "ss") + "s"
                customSize: 13
                font.weight: Font.DemiBold
                color: root.contrastMuted
            }

            ThemedText {
                visible: !SettingsService.lockScreen24h
                text: SystemInfoService.currentTime.getHours() >= 12 ? "PM" : "AM"
                customSize: 13
                font.weight: Font.Bold
                color: Theme.accent
            }
        }
    }

    // Formatted Date (respects SettingsService.clockShowDate)
    ThemedText {
        Layout.alignment: Qt.AlignHCenter
        visible: SettingsService.lockScreenShowDate
        text: Qt.formatDate(SystemInfoService.currentTime, "ddd · dd MMM · yyyy").toUpperCase()
        customSize: Constants.sizeSm
        font.letterSpacing: 3
        font.bold: true
        color: root.contrastMuted
    }

    // Battery Status Pill (uses Veyra's existing battery monitor)
    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: SettingsService.lockScreenShowBattery && SystemInfoService.hasBattery
        implicitWidth: batteryLayout.implicitWidth + Constants.sizeXl
        implicitHeight: Constants.size3Xl

        ThemedShadow {
            anchors.fill: batteryPillBg
            radius: batteryPillBg.radius
            active: true
            opacity: Theme.isDark ? 0.5 : 0.25
        }

        Rectangle {
            id: batteryPillBg
            anchors.fill: parent
            radius: height / 2
            color: Theme.bg
            border.color: Theme.border
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius
                color: Theme.bgSecondary
            }

            RowLayout {
                id: batteryLayout
                anchors.centerIn: parent
                spacing: Constants.sizeXs

                SvgIcon {
                    icon: {
                        if (SystemInfoService.batteryStatus === "Charging")
                            return "battery-charging";
                        if (SystemInfoService.batteryLevel <= 15)
                            return "battery-low";
                        if (SystemInfoService.batteryLevel >= 80)
                            return "battery-full";
                        return "battery-medium";
                    }
                    iconSize: 14
                    iconColor: SystemInfoService.batteryLevel <= 15 ? Theme.accentComplementary : Theme.accent
                    flat: true
                }

                ThemedText {
                    text: SystemInfoService.batteryLevel + "%"
                    customSize: 11
                    font.bold: true
                    color: root.contrastText
                }

                ThemedText {
                    visible: SystemInfoService.batteryStatus === "Charging"
                    text: "CHARGING"
                    customSize: 9
                    font.bold: true
                    color: root.contrastMuted
                }
            }
        }
    }

    // Now Playing Pill (if music is playing or available)
    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root.hasMedia && SettingsService.lockScreenShowMedia
        implicitWidth: musicLayout.implicitWidth + Constants.sizeXl
        implicitHeight: Constants.size3Xl

        ThemedShadow {
            anchors.fill: musicPillBg
            radius: musicPillBg.radius
            active: true
            opacity: Theme.isDark ? 0.5 : 0.25
        }

        Rectangle {
            id: musicPillBg

            anchors.fill: parent
            radius: height / 2
            color: Theme.bg
            border.color: Theme.border
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius
                color: Theme.bgSecondary
            }

            RowLayout {
                id: musicLayout

                anchors.centerIn: parent
                spacing: Constants.sizeSm

                Item {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    Layout.alignment: Qt.AlignVCenter
                    visible: lockArtImg.status === Image.Ready && (lockArtImg.source + "").trim() !== ""

                    Image {
                        id: lockArtImg

                        anchors.fill: parent
                        source: root.activePlayer ? (root.activePlayer.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        mipmap: true
                        visible: false
                    }

                    Rectangle {
                        id: lockArtMask

                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: lockArtImg
                        maskSource: lockArtMask
                    }

                }

                MiniCavaBars {
                    Layout.alignment: Qt.AlignVCenter
                    barColor: Theme.accent
                    maxBarHeight: Constants.sizeSm
                    minBarHeight: 3
                    barWidth: Constants.size3Xs
                    isPlaying: MprisService.isPlaying
                }

                ThemedText {
                    visible: SettingsService.lockScreenShowMediaState
                    text: MprisService.isPlaying ? "PLAYING" : "PAUSED"
                    customSize: 8
                    font.bold: true
                    color: root.contrastMuted
                }

                ThemedText {
                    text: {
                        let p = root.activePlayer;
                        if (!p)
                            return "";

                        let artist = (p.trackArtist || "").trim();
                        let title = (p.trackTitle || "").trim();
                        return artist ? (artist + " — " + title) : title;
                    }
                    customSize: 11
                    color: root.contrastText
                    elide: Text.ElideRight
                    Layout.maximumWidth: 340
                }

            }

        }

    }

    // Quote (when music is not playing)
    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        visible: !root.hasMedia || !SettingsService.lockScreenShowMedia
        spacing: Constants.size3Xs

        ThemedText {
            Layout.alignment: Qt.AlignHCenter
            text: QuoteService.currentQuote.text ? ("“" + QuoteService.currentQuote.text + "”") : ""
            customSize: 11
            font.italic: true
            color: root.contrastMuted
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.maximumWidth: 440
        }

        ThemedText {
            Layout.alignment: Qt.AlignHCenter
            visible: QuoteService.currentQuote.author !== ""
            text: QuoteService.currentQuote.author ? ("— " + QuoteService.currentQuote.author.toUpperCase()) : ""
            customSize: 9
            font.letterSpacing: 1.5
            color: root.contrastMuted
            opacity: 0.7
        }

    }

}
