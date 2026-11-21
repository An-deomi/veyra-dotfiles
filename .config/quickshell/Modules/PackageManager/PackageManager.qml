import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.PackageManager.Components

AppWindow {
    id: root

    property alias searchText: controller.searchText
    property alias allResults: controller.allResults
    property alias installingPkg: controller.installingPkg
    property alias actionMode: controller.actionMode
    property alias selectedPackages: controller.selectedPackages
    property alias selectedPackageObjects: controller.selectedPackageObjects
    property alias currentDetailPkg: controller.currentDetailPkg
    property alias currentDetailText: controller.currentDetailText
    property alias resultsModel: controller.resultsModel
    property alias selectedCategory: controller.selectedCategory
    property alias currentSearchQuery: controller.currentSearchQuery
    property alias isSearching: controller.isSearching
    property alias searchFieldRef: pkgHeader.searchField
    readonly property alias searchField: pkgHeader.searchField
    readonly property var categoryList: controller.categoryList
    readonly property alias detailsOverlayRef: detailsOverlay
    readonly property alias pageTransitionRef: pageTransition
    readonly property alias contentCompRef: contentComp
    readonly property alias focusTimerRef: focusTimer

    function stopSearchTimers() {
        controller.stopSearchTimers();
    }

    function showPackageDetails(pkgName, installed) {
        controller.showPackageDetails(pkgName, installed);
        detailsOverlay.visible = true;
    }

    function restartDebounceTimer() {
        controller.restartDebounceTimer();
    }

    function isDebounceTimerRunning() {
        return controller.isDebounceTimerRunning();
    }

    function startFocusTimer() {
        focusTimer.start();
    }

    function focusSearch() {
        controller.focusSearch();
    }

    function switchMode(val) {
        controller.switchMode(val);
    }

    function switchCategory(cat) {
        controller.switchCategory(cat);
    }

    function doSearch(query) {
        controller.doSearch(query);
    }

    function updateModel() {
        controller.updateModel();
    }

    function toggleSelect(pkgName) {
        controller.toggleSelect(pkgName);
    }

    function executeBatch() {
        controller.executeBatch();
    }

    function confirmBatchAction() {
        batchConfirmDialog.open();
    }

    function installPackage(name) {
        controller.installPackage(name);
    }

    function removePackage(name) {
        controller.removePackage(name);
    }

    function handleKeyPress(event, fromSearch) {
        controller.handleKeyPress(event, fromSearch);
    }

    function triggerDelayedFocus() {
        startFocusTimer();
    }

    // Keep the package manager as a centered utility window, not a maximized workspace.
    width: 1120
    height: 720
    minimumSize: Qt.size(900, 560)
    maximumSize: Qt.size(1360, 860)

    widgetId: "packagemanager"
    windowTitle: "Veyra Package Manager"
    contentPadding: 0
    onIsOpenChanged: {
        if (isOpen) {
            controller.stopSearchTimers();
            controller.isSearching = false;
            controller.currentSearchQuery = "";
            if (pkgHeader.searchField)
                pkgHeader.searchField.textField.text = "";

            controller.allResults = [];
            controller.installingPkg = "";
            controller.actionMode = SettingsService.packageManagerMode || "install";
            controller.selectedPackages = [];
            controller.selectedPackageObjects = ({
            });
            controller.doSearch("");
        } else {
            controller.stopSearchTimers();
            controller.isSearching = false;
            SettingsService.packageManagerMode = "install";
        }
    }
    Component.onCompleted: {
        if (isOpen)
            controller.doSearch("");

    }
    onWindowReadyForFocus: {
        if (contentComp)
            contentComp.focusListView();

    }

    PackageManagerController {
        id: controller

        visible: false
        managerRoot: root
    }

    Timer {
        id: focusTimer

        interval: 50
        repeat: false
        onTriggered: {
            if (contentComp)
                contentComp.focusListView();

        }
    }

    Shortcut {
        sequence: "/"
        onActivated: {
            if (!searchField.textField.activeFocus && !detailsOverlay.visible)
                root.focusSearch();

        }
    }

    Shortcut {
        sequence: "Ctrl+I"
        onActivated: {
            let listV = contentComp ? contentComp.getListView() : null;
            let idx = (listV && listV.currentIndex >= 0) ? listV.currentIndex : 0;
            if (controller.resultsModel.count > idx) {
                let pkg = controller.resultsModel.get(idx);
                root.showPackageDetails(pkg.name, pkg.installed);
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Tab"
        onActivated: {
            let modes = ["install", "remove", "update"];
            let idx = modes.indexOf(root.actionMode);
            if (idx === -1)
                idx = 0;

            root.switchMode(modes[(idx + 1) % modes.length]);
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        onActivated: {
            let modes = ["install", "remove", "update"];
            let idx = modes.indexOf(root.actionMode);
            if (idx === -1)
                idx = 0;

            root.switchMode(modes[(idx - 1 + modes.length) % modes.length]);
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        PackageManagerSidebar {
            id: sidebar

            managerRoot: root
        }

        Item {
            id: mainContentContainer

            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                id: mainContentCol

                anchors.fill: parent
                spacing: 0

                PackageManagerHeader {
                    id: pkgHeader

                    managerRoot: root
                    contentComp: contentComp
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: Constants.sizeLg

                    PageTransitionView {
                        id: pageTransition

                        anchors.fill: parent

                        PackageManagerContent {
                            id: contentComp

                            anchors.fill: parent
                            managerRoot: root
                        }

                    }

                }

            }

            PackageDetailsOverlay {
                id: detailsOverlay

                anchors.fill: parent
                visible: false
                managerRoot: root
                z: 100
            }

        }

    }



    Dialog {
        id: batchConfirmDialog

        modal: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(460, root.width - 40)
        title: root.actionMode === "remove"
            ? "Review package removal"
            : root.actionMode === "update" ? "Review system updates" : "Review installation"
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: controller.executeBatchConfirmed()

        contentItem: ColumnLayout {
            spacing: Constants.sizeSm

            ThemedText {
                Layout.fillWidth: true
                text: root.actionMode === "remove"
                    ? "The selected packages will be removed with unused dependencies. Review the list before continuing."
                    : root.actionMode === "update"
                        ? "The selected updates will be passed to your AUR helper for review and confirmation in the terminal."
                        : "The selected packages will be passed to your AUR helper for review and confirmation in the terminal."
                color: Theme.muted
                customSize: Constants.sizeSm
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(190, packageList.implicitHeight + Constants.sizeMd * 2)
                radius: Constants.sizeSm
                color: Theme.bgSecondary
                border.width: 1
                border.color: Theme.border
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: Constants.sizeSm
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        id: packageList
                        width: parent.width
                        spacing: Constants.size2Xs

                        Repeater {
                            model: root.selectedPackages
                            delegate: ThemedText {
                                required property var modelData
                                Layout.fillWidth: true
                                text: "•  " + String(modelData)
                                customSize: Constants.sizeSm
                                color: Theme.fg
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            ThemedText {
                Layout.fillWidth: true
                text: root.selectedPackages.length + " package(s) selected"
                color: Theme.accent
                font.weight: Font.DemiBold
                customSize: Constants.sizeXs + 1
            }
        }
    }
}
