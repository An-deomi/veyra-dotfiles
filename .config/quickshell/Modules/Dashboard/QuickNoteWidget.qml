import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Card {
    id: root

    property bool noteLoading: false
    property bool copied: false
    property bool ownsInputFocus: false
    readonly property string notePath: XdgPaths.stateDir + "/quick_note.txt"

    function saveNote() {
        if (XdgPaths.safeTestMode || saveProc.running)
            return;

        saveProc.stdinEnabled = true;
        saveProc.command = [
            "python3",
            Quickshell.shellDir + "/Scripts/system/write_text.py",
            root.notePath,
            "600"
        ];
        saveProc.running = true;
        saveProc.write(noteArea.text);
        saveProc.stdinEnabled = false;
    }

    function copyNote() {
        if (noteArea.text === "" || copyProc.running)
            return;

        copyProc.stdinEnabled = true;
        copyProc.command = ["wl-copy"];
        copyProc.running = true;
        copyProc.write(noteArea.text);
        copyProc.stdinEnabled = false;
        root.copied = true;
        copiedTimer.restart();
    }

    contentPadding: Constants.sizeMd
    implicitWidth: 350
    implicitHeight: noteCol.implicitHeight + root.contentPadding * 2

    Component.onDestruction: {
        if (root.ownsInputFocus) {
            root.ownsInputFocus = false;
            AppState.textInputActive = false;
        }
    }

    FileView {
        id: noteFile

        path: root.notePath
        printErrors: false
        onLoaded: {
            const loaded = text();
            if (loaded !== noteArea.text) {
                root.noteLoading = true;
                noteArea.text = loaded;
                root.noteLoading = false;
            }
        }
    }

    Timer {
        id: saveTimer

        interval: 350
        repeat: false
        onTriggered: root.saveNote()
    }

    Timer {
        id: copiedTimer

        interval: 1500
        repeat: false
        onTriggered: root.copied = false
    }

    Process {
        id: saveProc
    }

    Process {
        id: copyProc
    }

    ColumnLayout {
        id: noteCol

        anchors.fill: parent
        spacing: Constants.sizeXs

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            SvgIcon {
                icon: "code"
                iconSize: 13
                iconColor: Theme.accent
                flat: true
            }

            ThemedText {
                text: "QUICK NOTE"
                customSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.8
                color: Theme.muted
                Layout.fillWidth: true
            }

            Rectangle {
                visible: noteArea.text.length > 0
                Layout.preferredHeight: 22
                Layout.preferredWidth: copyLabel.implicitWidth + 14
                radius: height / 2
                color: root.copied ? Chrome.accentTintStrong : Theme.bgSecondary
                border.width: 1
                border.color: root.copied ? Theme.accent : Theme.border

                ThemedText {
                    id: copyLabel

                    anchors.centerIn: parent
                    text: root.copied ? "Copied!" : "Copy"
                    customSize: 10
                    font.weight: Font.DemiBold
                    color: root.copied ? Theme.accent : Theme.fg
                }

                TapHandler {
                    onTapped: root.copyNote()
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Rectangle {
                visible: noteArea.text.length > 0
                Layout.preferredHeight: 22
                Layout.preferredWidth: clearLabel.implicitWidth + 14
                radius: height / 2
                color: Theme.bgSecondary
                border.width: 1
                border.color: Theme.border

                ThemedText {
                    id: clearLabel

                    anchors.centerIn: parent
                    text: "Clear"
                    customSize: 10
                    color: Theme.muted
                }

                TapHandler {
                    onTapped: {
                        saveTimer.stop();
                        noteArea.text = "";
                        root.saveNote();
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            radius: Constants.sizeMd
            color: Theme.bgSecondary
            border.width: 1
            border.color: noteArea.activeFocus ? Theme.accent : Theme.border
            clip: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    root.ownsInputFocus = true;
                    AppState.textInputActive = true;
                    noteArea.forceActiveFocus();
                }
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: Constants.sizeXs
                contentWidth: availableWidth
                clip: true

                TextArea {
                    id: noteArea

                    width: parent.width
                    font.family: Constants.fontFamily
                    font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
                    color: Theme.fg
                    placeholderText: "Jot down a quick note, command, or snippet…"
                    placeholderTextColor: Theme.muted
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.isDark ? Theme.opaqueBg : Theme.fg
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    background: null
                    padding: 2

                    onTextChanged: {
                        if (!root.noteLoading)
                            saveTimer.restart();
                    }

                    onActiveFocusChanged: {
                        root.ownsInputFocus = activeFocus;
                        AppState.textInputActive = activeFocus;
                    }

                    Keys.onEscapePressed: {
                        noteArea.focus = false;
                        root.ownsInputFocus = false;
                        AppState.textInputActive = false;
                    }
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Constants.animFast
                }
            }
        }
    }
}
