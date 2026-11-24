import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Item {
    id: root

    property var notifData
    property int iconSize: Constants.size3Xl
    property color iconColor: Theme.accent
    property color bgColor: Theme.bgSecondary
    property bool primaryImageFailed: false
    readonly property string primaryImageSource: (notifData && notifData.image && !primaryImageFailed) ? String(notifData.image) : ""
    readonly property string fallbackAppIconSource: {
        if (!notifData || !notifData.appIcon || notifData.appIcon === "")
            return "";
        if (notifData.appIcon.startsWith("file://"))
            return notifData.appIcon;
        if (notifData.appIcon.startsWith("/"))
            return "file://" + notifData.appIcon;
        return "image://icon/" + notifData.appIcon;
    }
    readonly property string resolvedImageSource: primaryImageSource !== "" ? primaryImageSource : fallbackAppIconSource
    property bool hasAppIcon: resolvedImageSource !== "" && appImage.status !== Image.Error
    property bool isUrgencyIcon: !hasAppIcon

    onNotifDataChanged: primaryImageFailed = false

    Connections {
        target: root.notifData ? root.notifData : null
        ignoreUnknownSignals: true
        function onImageChanged() {
            root.primaryImageFailed = false;
        }
    }

    function getUrgencyIcon() {
        if (!notifData)
            return "info-filled";

        if (notifData.urgency === 2)
            return "warning";

        if (notifData.urgency === 0)
            return "info";

        return "info-filled";
    }

    SvgIcon {
        anchors.fill: parent
        visible: !root.hasAppIcon
        icon: root.hasAppIcon ? "" : getUrgencyIcon()
        iconSize: root.isUrgencyIcon ? Constants.sizeLg : Constants.size2Xl
        iconColor: root.iconColor
        flat: root.isUrgencyIcon
        bgColor: root.isUrgencyIcon ? "transparent" : root.bgColor
        isCircle: false
    }

    Rectangle {
        id: imageBg

        anchors.fill: parent
        visible: root.hasAppIcon
        color: "transparent"
        radius: Constants.sizeXs

        Image {
            id: appImage

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignLeft
            source: root.resolvedImageSource
            onStatusChanged: {
                if (status === Image.Error && root.primaryImageSource !== "")
                    root.primaryImageFailed = true;
            }
            sourceSize: Qt.size(root.width > 0 ? root.width : root.iconSize, root.height > 0 ? root.height : root.iconSize)
            layer.enabled: true

            layer.effect: OpacityMask {

                maskSource: Rectangle {
                    width: root.width > 0 ? root.width : root.iconSize
                    height: root.height > 0 ? root.height : root.iconSize
                    radius: Constants.sizeXs
                }

            }

        }

    }

}
