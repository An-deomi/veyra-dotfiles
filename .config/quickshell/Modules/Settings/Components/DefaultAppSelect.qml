import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property var pageRoot: null
    property string role: ""
    property string label: ""
    property string description: ""
    property string iconName: "apps"

    Layout.fillWidth: true
    implicitHeight: Math.max(78, rowLayout.implicitHeight + Constants.sizeSm * 2)
    implicitWidth: 420

    function syncIndex() {
        if (!pageRoot || !appSelect)
            return;
        const options = pageRoot.optionsFor(role);
        const selected = pageRoot.currentFor(role);
        const index = options.indexOf(selected);
        appSelect.currentIndex = index >= 0 ? index : 0;
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Constants.sizeMd
        color: rowHover.hovered ? Theme.bgTertiary : Theme.bgSecondary
        border.width: 1
        border.color: rowHover.hovered ? Theme.accent : Theme.border

        Behavior on color {
            enabled: HyprlandService.enableAnimations
            ColorAnimation { duration: Constants.animFast }
        }
        Behavior on border.color {
            enabled: HyprlandService.enableAnimations
            ColorAnimation { duration: Constants.animFast }
        }
    }

    HoverHandler {
        id: rowHover
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: Constants.sizeMd
        anchors.rightMargin: Constants.sizeMd
        anchors.topMargin: Constants.sizeSm
        anchors.bottomMargin: Constants.sizeSm
        spacing: Constants.sizeMd

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            radius: Constants.sizeSm
            color: Theme.bgAccent

            SvgIcon {
                anchors.centerIn: parent
                icon: root.iconName
                iconSize: Constants.sizeLg
                iconColor: Theme.accent
                flat: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 70
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            ThemedText {
                Layout.fillWidth: true
                text: root.label
                color: Theme.fg
                customSize: Constants.sizeSm
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            ThemedText {
                Layout.fillWidth: true
                text: root.description
                color: Theme.muted
                customSize: Constants.sizeXs + 2
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        ThemedSelect {
            id: appSelect
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 230
            Layout.minimumWidth: 170
            Layout.maximumWidth: 260
            label: ""
            description: ""
            comboWidth: Math.max(135, width - Constants.sizeLg * 2)
            model: root.pageRoot ? root.pageRoot.optionsFor(root.role) : ["__none__"]
            textMap: root.pageRoot ? root.pageRoot.namesFor(root.role) : ({"__none__": "Loading apps…"})
            onActivated: (index) => {
                if (!root.pageRoot)
                    return;
                const options = root.pageRoot.optionsFor(root.role);
                const selected = options[index];
                if (selected !== undefined && selected !== "__none__")
                    root.pageRoot.chooseApp(root.role, selected);
            }
            Component.onCompleted: root.syncIndex()
            onModelChanged: root.syncIndex()
        }
    }

    Connections {
        target: root.pageRoot
        ignoreUnknownSignals: true
        function onAppInfoChanged() { root.syncIndex(); }
    }

    Connections {
        target: SettingsService
        function onDefaultTerminalCommandChanged() { if (root.role === "terminal") root.syncIndex(); }
        function onDefaultBrowserAppIdChanged() { if (root.role === "browser") root.syncIndex(); }
        function onDefaultCodingAppIdChanged() { if (root.role === "coding") root.syncIndex(); }
        function onDefaultFileManagerAppIdChanged() { if (root.role === "fileManager") root.syncIndex(); }
        function onDefaultTextEditorAppIdChanged() { if (root.role === "textEditor") root.syncIndex(); }
        function onDefaultImageViewerAppIdChanged() { if (root.role === "imageViewer") root.syncIndex(); }
        function onDefaultVideoPlayerAppIdChanged() { if (root.role === "videoPlayer") root.syncIndex(); }
        function onDefaultMusicPlayerAppIdChanged() { if (root.role === "musicPlayer") root.syncIndex(); }
        function onDefaultPdfViewerAppIdChanged() { if (root.role === "pdfViewer") root.syncIndex(); }
    }
}
