import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows

Item {
    id: root

    property bool isOpen: false
    property string mode: "out"
    signal modeRequested(string requestedMode)
    property var devices: []
    property string defaultName: ""
    property var streams: []
    property string lastRaw: ""
    property real lastAction: 0
    property string pendingStream: ""
    property int pendingVolume: 0
    readonly property bool isOut: mode === "out"
    readonly property string script: Quickshell.shellDir + "/Modules/ControlCenter/scripts/audio.py"
    readonly property string streamKind: isOut ? "sink-input" : "source-output"
    readonly property var trackedPipewireStreams: Pipewire.nodes.values.filter((node) => node && node.isStream && node.audio !== null)
    readonly property var deviceLabels: {
        let l = [];
        for (let i = 0; i < devices.length; i++)
            l.push(devices[i].desc);

        return l;
    }
    readonly property int defaultIndex: {
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].name === defaultName)
                return i;

        }
        return -1;
    }

    function deviceIndexFor(id) {
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].id === id)
                return i;

        }
        return -1;
    }

    function refresh() {
        if (stateProc.running)
            return ;
        // Do not launch the polling helper during an active audio interaction.
        if (Date.now() - root.lastAction < 900) {
            refreshSoon.restart();
            return;
        }
        stateProc.command = ["python3", root.script, "state", root.mode];
        stateProc.running = true;
    }

    function touch() {
        lastAction = Date.now();
        refreshSoon.restart();
    }

    function setDefault(i) {
        if (i < 0 || i >= devices.length)
            return ;

        defaultName = devices[i].name;
        touch();
        Quickshell.execDetached(["pactl", isOut ? "set-default-sink" : "set-default-source", devices[i].name]);
    }

    function moveStream(id, i) {
        if (i < 0 || i >= devices.length)
            return ;

        touch();
        Quickshell.execDetached(["pactl", "move-" + streamKind, String(id), String(devices[i].id)]);
    }

    function pipeNodeForStream(id) {
        const nodes = Pipewire.nodes.values;
        const wantedId = String(id);
        const wantedClass = root.isOut ? "Stream/Output/Audio" : "Stream/Input/Audio";
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            if (!node || !node.isStream || !node.audio)
                continue;
            const props = node.properties || {};
            const serial = props["object.serial"] !== undefined ? props["object.serial"] : props["pulse.id"];
            if (String(serial) === wantedId && String(props["media.class"] || "") === wantedClass)
                return node;
        }
        return null;
    }

    function sameStreamLayout(oldStreams, newStreams) {
        if (!oldStreams || oldStreams.length !== newStreams.length)
            return false;
        for (let i = 0; i < newStreams.length; i++) {
            const a = oldStreams[i];
            const b = newStreams[i];
            if (String(a.id) !== String(b.id) || a.app !== b.app || a.media !== b.media || a.device !== b.device || a.muted !== b.muted)
                return false;
        }
        return true;
    }

    function setStreamVolume(id, v) {
        const percent = Math.round(Math.max(0, Math.min(root.isOut ? 150 : 100, v)));
        const pipeNode = root.pipeNodeForStream(id);
        lastAction = Date.now();

        // Direct PipeWire property writes avoid launching pactl for every small slider movement.
        if (pipeNode && pipeNode.audio) {
            const targetVolume = percent / 100;
            if (Math.abs(pipeNode.audio.volume - targetVolume) > 0.004)
                pipeNode.audio.volume = targetVolume;
            refreshSoon.restart();
            return;
        }

        // Keep a pactl fallback for streams not exposed as a matching PipeWire node.
        pendingStream = String(id);
        pendingVolume = percent;
        if (!volTimer.running)
            volTimer.start();
        refreshSoon.restart();
    }

    function toggleMute(id) {
        const pipeNode = root.pipeNodeForStream(id);
        if (pipeNode && pipeNode.audio) {
            pipeNode.audio.muted = !pipeNode.audio.muted;
            lastAction = Date.now();
            refreshSoon.restart();
            return;
        }
        touch();
        Quickshell.execDetached(["pactl", "set-" + streamKind + "-mute", String(id), "toggle"]);
    }

    onModeChanged: {
        devices = [];
        streams = [];
        defaultName = "";
        lastRaw = "";
        refresh();
    }
    onIsOpenChanged: {
        if (isOpen) {
            lastRaw = "";
            refresh();
        }
    }

    PwObjectTracker {
        objects: root.trackedPipewireStreams
    }

    Timer {
        interval: 2500
        running: root.isOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshSoon

        interval: 1000
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: volTimer

        interval: 80
        repeat: false
        onTriggered: Quickshell.execDetached(["pactl", "set-" + root.streamKind + "-volume", root.pendingStream, root.pendingVolume + "%"])
    }

    Process {
        id: stateProc

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                if (Date.now() - root.lastAction < 900)
                    return ;

                if (data === root.lastRaw)
                    return ;

                try {
                    let d = JSON.parse(data.trim());
                    root.lastRaw = data;
                    root.devices = d.devices || [];
                    root.defaultName = d["default"] || "";
                    const incomingStreams = d.streams || [];
                    if (!root.sameStreamLayout(root.streams, incomingStreams))
                        root.streams = incomingStreams;
                } catch (e) {
                }
            }
        }

    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: Constants.sizeSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeXs

                Repeater {
                    model: [
                        { "label": "Output", "value": "out", "icon": "volume" },
                        { "label": "Input", "value": "in", "icon": "microphone" }
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: Constants.sizeSm
                        color: root.mode === modelData.value ? Theme.accent : Theme.bgSecondary
                        border.width: 1
                        border.color: root.mode === modelData.value ? Theme.accent : Theme.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Constants.sizeXs

                            SvgIcon {
                                icon: modelData.icon
                                iconSize: Constants.sizeSm
                                iconColor: root.mode === modelData.value ? Theme.bg : Theme.fg
                                flat: true
                            }

                            ThemedText {
                                text: modelData.label
                                customSize: Constants.sizeSm
                                font.bold: root.mode === modelData.value
                                color: root.mode === modelData.value ? Theme.bg : Theme.fg
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.mode !== modelData.value)
                                    root.modeRequested(modelData.value);
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: Constants.animFast }
                        }
                    }
                }
            }

            VolumeSlider {
                id: masterOutputSlider
                visible: root.isOut
                Layout.fillWidth: true
                label: "Master output"
            }

            ThemedText {
                visible: root.isOut && masterOutputSlider.volume > 100
                text: "Volume boost is active; high levels may cause distortion."
                customSize: 10
                color: Theme.muted
                Layout.leftMargin: Constants.sizeSm
            }

            ThemedSlider {
                visible: !root.isOut
                Layout.fillWidth: true
                label: "Microphone input"
                enabled: AudioService.hasPhysicalMic
                value: AudioService.micVolume
                icon: AudioService.micMuted ? "microphone-off" : "microphone"
                onMoved: (val) => AudioService.setMicVolume(val)
                onIconClicked: AudioService.setMicMuted(!AudioService.micMuted)
            }

            ThemedText {
                visible: !root.isOut && !AudioService.hasPhysicalMic
                text: "No physical microphone detected"
                color: Theme.muted
                Layout.leftMargin: Constants.sizeSm
            }

            ThemedSelect {
                id: devSelect

                Layout.fillWidth: true
                label: root.isOut ? "Output device" : "Input device"
                description: root.devices.length === 0 ? "No devices found" : (root.isOut ? "Where new sound plays" : "What new apps record from")
                comboWidth: 170
                model: root.deviceLabels
                onActivated: (index) => root.setDefault(index)

                Binding {
                    target: devSelect
                    property: "currentIndex"
                    value: root.defaultIndex
                }

            }

            ThemedText {
                text: root.isOut ? "APPLICATION VOLUME" : "APPLICATION INPUTS"
                customSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.8
                color: Theme.muted
                Layout.leftMargin: Constants.sizeSm
                Layout.topMargin: Constants.sizeSm
            }

            ThemedText {
                visible: root.streams.length === 0
                text: root.isOut ? "No application audio streams are active" : "No applications are recording right now"
                color: Theme.muted
                Layout.leftMargin: Constants.sizeSm
            }

            Repeater {
                model: root.streams

                Card {
                    Layout.fillWidth: true
                    cardRadius: Constants.sizeSm
                    useBorder: false
                    backgroundColor: Theme.bgSecondary
                    contentPadding: Constants.sizeMd

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Constants.sizeSm

                        ThemedSelect {
                            id: appSel

                            Layout.fillWidth: true
                            label: modelData.app
                            description: modelData.media
                            comboWidth: 170
                            model: root.deviceLabels
                            onActivated: (index) => root.moveStream(modelData.id, index)

                            Binding {
                                target: appSel
                                property: "currentIndex"
                                value: root.deviceIndexFor(modelData.device)
                            }
                        }

                        ThemedSlider {
                            readonly property var pipeNode: root.pipeNodeForStream(modelData.id)
                            Layout.fillWidth: true
                            enabled: true
                            to: root.isOut ? 150 : 100
                            value: pipeNode && pipeNode.audio ? pipeNode.audio.volume * 100 : modelData.volume
                            icon: (pipeNode && pipeNode.audio ? pipeNode.audio.muted : modelData.muted) ? (root.isOut ? "volume-off" : "microphone-off") : (root.isOut ? "volume" : "microphone")
                            onMoved: (val) => root.setStreamVolume(modelData.id, val)
                            onIconClicked: root.toggleMute(modelData.id)
                        }
                    }
                }
            }

        }

    }

}
