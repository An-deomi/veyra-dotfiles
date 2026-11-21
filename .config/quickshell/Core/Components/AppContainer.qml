import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    default property alias content: contentLayout.data
    property string pageTitle: ""
    property string pageDescription: ""
    property string pageIcon: ""
    property int contentPadding: Constants.sizeLg
    // Settings pages read better as one column of a bounded width: at a wide
    // window the old full-bleed cards put the label and its control hundreds of
    // pixels apart. The column stays centred and shrinks on narrow windows.
    property int maxContentWidth: 1080

    // Fold or unfold every AppGroup on this page (headers call this).
    function setAllCollapsed(collapsed) {
        for (let i = 0; i < contentLayout.children.length; i++) {
            let child = contentLayout.children[i];
            if (child && child.collapsible !== undefined && child.expanded !== undefined)
                child.expanded = !collapsed;
        }
    }

    // A search result was clicked: scroll the row into view and flash it.
    // Pages are rebuilt when the tab changes, so this also runs from a poll
    // timer until the requested label exists on the page.
    function applyPendingFocus() {
        let label = AppState.pendingSettingLabel;
        if (label === "")
            return false;
        let target = root.findControl(label, AppState.pendingSettingGroup);
        if (!target)
            return false;
        AppState.pendingSettingLabel = "";
        AppState.pendingSettingGroup = "";
        root.revealControl(target);
        return true;
    }

    function findControl(label, group) {
        let matches = [];
        root.collectControls(contentLayout, label, matches);
        if (matches.length === 0)
            return null;
        for (let i = 0; i < matches.length; i++) {
            let node = matches[i].parent;
            while (node && node !== flickable.contentItem) {
                if (node.title !== undefined && node.title === group)
                    return matches[i];
                node = node.parent;
            }
        }
        return matches[0];
    }

    function collectControls(item, label, found) {
        if (!item || item === highlightRing)
            return ;
        if (item.label !== undefined && item.label === label)
            found.push(item);
        let kids = item.children || [];
        for (let i = 0; i < kids.length; i++)
            root.collectControls(kids[i], label, found);
    }

    function revealControl(target) {
        // Open any folded group the row lives in.
        let node = target.parent;
        while (node && node !== flickable.contentItem) {
            if (node.collapsible !== undefined && node.expanded !== undefined)
                node.expanded = true;
            node = node.parent;
        }
        scrollTimer.target = target;
        scrollTimer.restart();
    }

    property int pendingAttempts: 0

    Connections {
        target: AppState

        function onPendingSettingLabelChanged() {
            root.pendingAttempts = 0;
        }
    }

    Timer {
        interval: 150
        repeat: true
        running: AppState.pendingSettingLabel !== "" && root.pendingAttempts < 20

        onTriggered: {
            if (root.applyPendingFocus())
                root.pendingAttempts = 0;
            else
                root.pendingAttempts += 1;
        }
    }

    Timer {
        id: scrollTimer

        property var target: null

        interval: 80

        onTriggered: {
            if (!target)
                return ;
            // Content positions are only final after the group re-expands.
            let pos = target.mapToItem(flickable.contentItem, 0, 0);
            let maxY = Math.max(0, flickable.contentHeight - flickable.height);
            flickable.contentY = Math.max(0, Math.min(maxY, pos.y - flickable.height / 3));
            Qt.callLater(() => root.showHighlight(target));
        }
    }

    function showHighlight(target) {
        if (!target || target.height <= 0)
            return ;
        // The ring lives in the container, outside the Flickable, so positions
        // are mapped to the container instead of to the scrolling content.
        let pos = target.mapToItem(root, 0, 0);
        highlightRing.x = flickable.x + Math.max(0, (flickable.width - mainCard.width) / 2 - 6);
        highlightRing.y = pos.y - 3;
        highlightRing.width = mainCard.width + 12;
        highlightRing.height = target.height + 6;
        highlightAnim.restart();
    }

    Layout.fillWidth: true
    Layout.fillHeight: true

    Flickable {
        id: flickable

        anchors.fill: parent
        anchors.margins: root.contentPadding
        clip: true
        interactive: true
        contentWidth: width
        contentHeight: mainCard.implicitHeight + Constants.sizeXl

        ColumnLayout {
            id: mainCard

            width: Math.min(flickable.width, root.maxContentWidth)
            x: Math.round((flickable.width - width) / 2)
            spacing: Constants.sizeLg

            ColumnLayout {
                id: contentLayout

                Layout.fillWidth: true
                spacing: Constants.sizeLg
            }
        }

        ScrollIndicator.vertical: ScrollIndicator {
            parent: flickable.parent
            anchors.top: flickable.top
            anchors.bottom: flickable.bottom
            anchors.right: flickable.right
        }

    }

    // Flashes around the row a search result scrolled to. It is a sibling of
    // the Flickable (not a child) so its coordinates are the visible viewport,
    // not the scrolling content.
    Rectangle {
        id: highlightRing

        visible: false
        color: "transparent"
        border.width: 1
        border.color: Theme.accent
        radius: Constants.sizeXs
        opacity: 0
        z: 100

        SequentialAnimation {
            id: highlightAnim

            PropertyAction { target: highlightRing; property: "opacity"; value: 0 }
            PropertyAction { target: highlightRing; property: "visible"; value: true }
            NumberAnimation { target: highlightRing; property: "opacity"; to: 1; duration: 150 }
            PauseAnimation { duration: 1500 }
            NumberAnimation { target: highlightRing; property: "opacity"; to: 0; duration: 450 }
            PropertyAction { target: highlightRing; property: "visible"; value: false }
        }
    }

}
