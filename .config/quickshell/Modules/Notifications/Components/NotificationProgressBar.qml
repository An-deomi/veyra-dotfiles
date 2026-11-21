import QtQuick
import qs.Core
import qs.Core.Components

Rectangle {
    id: progressTrack

    property var notifData

    height: Constants.size3Xs
    radius: height / 2
    color: Theme.bgSecondary
    visible: notifData && notifData.summary !== "Volume" && notifData.summary !== "Brightness" && notifData.summary !== "Microphone"

    Rectangle {
        id: progressBar

        height: parent.height
        radius: height / 2
        color: Theme.accent
        // Notification progress arrives from untrusted IPC and can be NaN or
        // out of range; NaN would otherwise propagate into the width.
        width: {
            if (!notifData)
                return 0;

            const value = Number(notifData.progress);
            return parent.width * (Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0);
        }

        Behavior on width {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutQuad
            }

        }
    }

}
