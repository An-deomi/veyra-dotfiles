import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Clipboard.Components

Item {
    id: root

    property var widget: null
    property string searchText: ""
    property alias initialFocusItem: searchField
    property int maxVisibleItems: 8
    readonly property bool isSearching: searchField.text.trim() !== ""
    readonly property int currentItemCount: ClipboardService.filteredModel ? ClipboardService.filteredModel.count : 0
    readonly property int targetVisibleItems: {
        if (!isSearching)
            return maxVisibleItems;

        if (currentItemCount === 0)
            return maxVisibleItems;

        return Math.min(currentItemCount, maxVisibleItems);
    }
    property int visibleItems: targetVisibleItems
    property int preferredContentWidth: 700
    readonly property int searchBarHeight: Constants.size4Xl
    readonly property int filterBarHeight: 32
    readonly property int itemHeight: 44
    readonly property int listSpacing: Constants.sizeXs
    readonly property int layoutSpacing: Constants.sizeSm
    readonly property int visibleListHeight: (targetVisibleItems * itemHeight) + Math.max(0, (targetVisibleItems - 1) * listSpacing)

    function filterCount(filterKey) {
        if (filterKey === "pinned")
            return ClipboardService.pinnedEntries.length;
        if (filterKey === "all")
            return ClipboardService.model.count;
        let count = 0;
        for (let i = 0; i < ClipboardService.model.count; i++) {
            let item = ClipboardService.model.get(i);
            if (filterKey === "images" && item.isImage)
                count++;
            else if (filterKey === "text" && !item.isImage)
                count++;
        }
        return count;
    }
    property bool isClearingAll: false

    function closeWidget() {
        if (root.widget && typeof root.widget.close === "function")
            root.widget.close();
        else if (root.widget && root.widget.isOpen !== undefined)
            root.widget.isOpen = false;
        else
            AppState.activeWidget = "";
    }

    function startClearAllAnimation() {
        if (isClearingAll || ClipboardService.filteredModel.count === 0)
            return ;

        isClearingAll = true;
    }

    function resetClipboard() {
        isClearingAll = false;
        clipboardView.currentIndex = 0;
        searchField.text = "";
        ClipboardService.filterClipboard("", "all");
        ClipboardService.refresh();
        searchField.forceActiveFocus();
    }

    implicitWidth: preferredContentWidth
    implicitHeight: searchBarHeight + filterBarHeight + layoutSpacing * 2 + visibleListHeight
    width: parent && parent.width > 0 ? parent.width : implicitWidth
    height: parent && parent.height > 0 ? parent.height : implicitHeight
    Component.onCompleted: {
        resetClipboard();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.layoutSpacing

        Item {
            id: topSearchContainer

            Layout.fillWidth: true
            Layout.preferredHeight: Constants.size4Xl
            visible: !SettingsService.barConvexMode
        }

        RowLayout {
            id: filterBar
            Layout.fillWidth: true
            Layout.preferredHeight: root.filterBarHeight
            spacing: Constants.sizeXs

            Repeater {
                model: [
                    { "key": "all", "label": "All" },
                    { "key": "pinned", "label": "Pinned" },
                    { "key": "text", "label": "Text" },
                    { "key": "images", "label": "Images" }
                ]

                delegate: Rectangle {
                    id: filterChip
                    property var filterData: modelData
                    implicitWidth: filterLabel.implicitWidth + countLabel.implicitWidth + 25
                    Layout.preferredHeight: root.filterBarHeight
                    radius: height / 2
                    color: ClipboardService.currentFilter === filterData.key ? Theme.accent : Theme.bgSecondary
                    border.width: ClipboardService.currentFilter === filterData.key ? 0 : 1
                    border.color: Theme.border

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            id: filterLabel
                            text: filterChip.filterData.label
                            color: ClipboardService.currentFilter === filterChip.filterData.key ? (Theme.isDark ? "#101014" : "#ffffff") : Theme.fg
                            font.family: Constants.fontFamily
                            font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            id: countLabel
                            text: root.filterCount(filterChip.filterData.key)
                            color: ClipboardService.currentFilter === filterChip.filterData.key ? (Theme.isDark ? "#101014" : "#ffffff") : Theme.muted
                            font.family: Constants.fontFamily
                            font.pixelSize: Math.round((Constants.sizeSm - 1) * SettingsService.fontScale)
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    TapHandler {
                        onTapped: {
                            ClipboardService.filterClipboard(searchField.text, filterChip.filterData.key);
                            clipboardView.currentIndex = ClipboardService.filteredModel.count > 0 ? 0 : -1;
                            root.isClearingAll = false;
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: Constants.animFast }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            ThemedText {
                text: ClipboardService.pinStatus
                customSize: Constants.sizeXs
                color: Theme.accent
                visible: ClipboardService.pinStatus !== ""
                Layout.maximumWidth: 185
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: root.visibleListHeight
            clip: true

            GhostEmptyState {
                anchors.centerIn: parent
                visible: opacity > 0.001
                opacity: (ClipboardService.filteredModel.count === 0 && !ClipboardService.isDeleting && !root.isClearingAll) ? 1 : 0
                text: ClipboardService.currentFilter === "pinned" ? (searchField.text === "" ? "No pinned snippets yet — tap a star to save one" : "No pinned snippets match") : (searchField.text === "" ? (ClipboardService.currentFilter === "images" ? "No copied images yet" : "Clipboard is empty") : "No results found")
                isAnimating: visible

                Behavior on opacity {
                    NumberAnimation {
                        duration: Constants.animFast
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Item {
                id: listContainer

                anchors.fill: parent
                visible: ClipboardService.filteredModel.count > 0 || root.isClearingAll
                opacity: root.isClearingAll ? 0 : 1
                x: root.isClearingAll ? 40 : 0
                scale: root.isClearingAll ? 0.94 : 1
                transformOrigin: Item.Center

                ListView {
                    id: clipboardView

                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: ClipboardService.filteredModel
                    spacing: root.listSpacing
                    currentIndex: ClipboardService.filteredModel.count > 0 ? 0 : -1
                    highlightResizeDuration: 0
                    highlightMoveDuration: Constants.animFast
                    highlightFollowsCurrentItem: true
                    visible: ClipboardService.filteredModel.count > 0
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Down) {
                            if (SettingsService.barConvexMode && clipboardView.currentIndex === ClipboardService.filteredModel.count - 1) {
                                searchField.forceActiveFocus();
                                clipboardView.currentIndex = -1;
                            } else {
                                clipboardView.currentIndex = Math.min(clipboardView.currentIndex + 1, ClipboardService.filteredModel.count - 1);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (!SettingsService.barConvexMode && clipboardView.currentIndex === 0) {
                                searchField.forceActiveFocus();
                                clipboardView.currentIndex = -1;
                            } else {
                                clipboardView.currentIndex = Math.max(clipboardView.currentIndex - 1, 0);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            let idx = clipboardView.currentIndex;
                            if (idx >= 0) {
                                let item = ClipboardService.filteredModel.get(idx);
                                ClipboardService.copyEntry(item, root.closeWidget);
                                event.accepted = true;
                            }
                        } else if (event.key === Qt.Key_Delete) {
                            let idx = clipboardView.currentIndex;
                            if (idx >= 0 && ClipboardService.filteredModel.count > idx) {
                                let item = ClipboardService.filteredModel.get(idx);
                                if (item.isPinnedSnapshot) {
                                    ClipboardService.togglePin(item.itemId, item.text, "", false);
                                } else {
                                    let currentDelegate = clipboardView.currentItem;
                                    if (currentDelegate && typeof currentDelegate.startDeleteAnimation === "function")
                                        currentDelegate.startDeleteAnimation();
                                    else
                                        ClipboardService.deleteItem(idx, item.fullLine);
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    highlight: Item {
                        width: clipboardView.width
                        height: clipboardView.currentItem ? clipboardView.currentItem.height : 44
                        z: 1
                        opacity: (clipboardView.currentItem && clipboardView.currentItem.isDeletingAnim) ? 0 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: Constants.sizeLg
                            color: Theme.bgSecondary
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Constants.animFast
                            }

                        }

                    }

                    add: Transition {
                        NumberAnimation {
                            properties: "opacity"
                            from: 0
                            to: 1
                            duration: root.isSearching ? 0 : Constants.animFast
                            easing.type: Easing.OutQuint
                        }

                    }

                    populate: Transition {
                        NumberAnimation {
                            properties: "opacity"
                            from: 0
                            to: 1
                            duration: root.isSearching ? 0 : Constants.animFast
                            easing.type: Easing.OutQuint
                        }

                    }

                    delegate: ClipboardItemDelegate {
                        isCurrent: clipboardView.currentIndex === index && index >= 0
                        onCopyRequested: function(reqId, pinnedText, isPinnedSnapshot) {
                            if (isPinnedSnapshot)
                                ClipboardService.copyPinnedText(pinnedText, root.closeWidget);
                            else
                                ClipboardService.copyItem(reqId, root.closeWidget);
                        }
                        onPinRequested: function(reqId, itemText, fullLine, isImage) {
                            ClipboardService.togglePin(reqId, itemText, fullLine, isImage);
                        }
                        onDeleteRequested: function(fullLine) {
                            ClipboardService.deleteItem(index, fullLine);
                        }

                        Binding on itemText {
                            when: model.text !== undefined && model.text !== null
                            value: model.text
                        }

                        Binding on itemId {
                            when: model.itemId !== undefined && model.itemId !== null
                            value: model.itemId
                        }

                        Binding on itemFullLine {
                            when: model.fullLine !== undefined && model.fullLine !== null
                            value: model.fullLine
                        }

                        Binding on isImg {
                            when: model.isImage !== undefined && model.isImage !== null
                            value: model.isImage
                        }

                        Binding on isPinned {
                            when: model.isPinned !== undefined && model.isPinned !== null
                            value: model.isPinned
                        }

                        Binding on isPinnedSnapshot {
                            when: model.isPinnedSnapshot !== undefined && model.isPinnedSnapshot !== null
                            value: model.isPinnedSnapshot
                        }

                        Binding on pinnedText {
                            when: model.pinnedText !== undefined && model.pinnedText !== null
                            value: model.pinnedText
                        }

                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AlwaysOff
                        active: true
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Constants.animFast + 30
                        easing.type: Easing.OutQuad
                    }

                }

                Behavior on x {
                    NumberAnimation {
                        duration: Constants.animFast + 30
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Constants.animFast + 30
                        easing.type: Easing.OutCubic
                        onRunningChanged: {
                            if (!running && root.isClearingAll) {
                                if (ClipboardService.currentFilter === "pinned")
                                    ClipboardService.clearPinnedItems();
                                else
                                    ClipboardService.clearHistory();
                                root.isClearingAll = false;
                            }
                        }
                    }

                }

            }

        }

        Item {
            id: bottomSearchContainer

            Layout.fillWidth: true
            Layout.preferredHeight: Constants.size4Xl
            visible: SettingsService.barConvexMode
        }

    }

    RowLayout {
        id: searchRow

        parent: SettingsService.barConvexMode ? bottomSearchContainer : topSearchContainer
        anchors.fill: parent
        spacing: Constants.sizeXs

        ThemedSearchBar {
            id: searchField

            Layout.fillWidth: true
            preferredHeight: Constants.size4Xl
            placeholderText: "Search clipboard history and pinned snippets..."
            onSearchRequested: (text) => {
                return ClipboardService.filterClipboard(text, ClipboardService.currentFilter);
            }
            customSize: Constants.sizeMd
            textField.Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Down) {
                    clipboardView.currentIndex = Math.min(clipboardView.currentIndex + 1, ClipboardService.filteredModel.count - 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    clipboardView.currentIndex = Math.max(clipboardView.currentIndex - 1, 0);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    let idx = clipboardView.currentIndex >= 0 ? clipboardView.currentIndex : 0;
                    if (ClipboardService.filteredModel.count > idx) {
                        let item = ClipboardService.filteredModel.get(idx);
                        ClipboardService.copyEntry(item, root.closeWidget);
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Delete) {
                    let idx = clipboardView.currentIndex;
                    if (idx >= 0 && ClipboardService.filteredModel.count > idx) {
                        let item = ClipboardService.filteredModel.get(idx);
                        if (item.isPinnedSnapshot) {
                            ClipboardService.togglePin(item.itemId, item.text, "", false);
                        } else {
                            let currentDelegate = clipboardView.currentItem;
                            if (currentDelegate && typeof currentDelegate.startDeleteAnimation === "function")
                                currentDelegate.startDeleteAnimation();
                            else
                                ClipboardService.deleteItem(idx, item.fullLine);
                        }
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Escape) {
                    root.closeWidget();
                    event.accepted = true;
                }
            }
        }

        SvgIconButton {
            icon: "trash"
            iconColor: Theme.accent
            iconSize: Constants.sizeXl
            visible: ClipboardService.filteredModel.count > 0 || root.isClearingAll
            disabled: root.isClearingAll
            onClicked: root.startClearAllAnimation()
        }

    }

}
