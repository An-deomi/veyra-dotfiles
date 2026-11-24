import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Core
import qs.Core.Components

ThemedSlider {
    id: root

    property int brightness: 0
    property bool isVisible: true
    property bool hasBacklight: true

    function setBrightness(val) {
        if (!root.hasBacklight)
            return;
        let finalVal = Math.max(5, val);
        brightSetProc.command = ["brightnessctl", "s", finalVal + "%"];
        brightSetProc.running = true;
        root.brightness = finalVal;
    }

    visible: root.hasBacklight
    label: "Screen brightness"
    value: root.brightness
    icon: "sun"
    onMoved: (val) => {
        return root.setBrightness(val);
    }
    onIconClicked: {
        if (root.brightness <= 5)
            root.setBrightness(100);
        else
            root.setBrightness(5);
    }

    Timer {
        interval: 250
        running: root.isVisible && root.hasBacklight
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!brightGetProc.running)
                brightGetProc.running = true;
        }
    }

    Process {
        id: brightGetProc

        command: ["brightnessctl", "-m"]
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.hasBacklight = false;
        }

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                var parts = data.split(",");
                if (parts.length >= 4) {
                    var pct = parts[3];
                    if (pct.endsWith("%"))
                        pct = pct.substring(0, pct.length - 1);

                    if (!root.pressed)
                        root.brightness = parseInt(pct);

                }
            }
        }

    }

    Process {
        id: brightSetProc
    }

}
