import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Core
import qs.Core.Components

ThemedSlider {
    id: root

    property var sink: Pipewire.defaultAudioSink
    property int volume: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    enabled: !!(root.sink && root.sink.audio)
    label: "Output volume"
    value: root.volume
    to: 150
    icon: (root.muted || root.volume === 0) ? "volume-off" : "volume"
    onMoved: (val) => {
        if (sink && sink.audio) {
            if (sink.name)
                Quickshell.execDetached(["pactl", "set-sink-volume", sink.name, Math.round(val) + "%"]);
            else
                sink.audio.volume = val / 100;
        }
    }
    onIconClicked: {
        if (sink && sink.audio) {
            sink.audio.muted = !sink.audio.muted;
        }

    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

}
