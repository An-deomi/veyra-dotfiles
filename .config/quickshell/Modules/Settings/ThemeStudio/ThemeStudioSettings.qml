import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    pageTitle: "Theme Studio"
    pageDescription: "Build, preview, and save Veyra color palettes."
    pageIcon: "palette"
    property color draftBg: Theme.opaqueBg
    property color draftFg: Theme.fg
    property color draftAccent: Theme.accent
    property color draftComplementary: Theme.accentComplementary
    property string presetName: ""
    property string statusText: ""
    property var savedPresets: []

    function syncDraft() {
        draftBg = Theme.opaqueBg;
        draftFg = Theme.fg;
        draftAccent = Theme.accent;
        draftComplementary = Theme.accentComplementary;
    }

    function applyDraft() {
        Theme.generateFromWallpaper = false;
        Theme.applyScheme({
            name: "Custom",
            bg: String(draftBg),
            fg: String(draftFg),
            accent: String(draftAccent),
            accentComplementary: String(draftComplementary)
        });
        statusText = "Custom palette applied. Wallpaper automation is paused until you enable it again.";
    }

    function applyWallpaperVariant(dark) {
        if (!Theme.wallpaperColors || !Theme.wallpaperColors.dark || !Theme.wallpaperColors.light) {
            statusText = "Generate a wallpaper palette first by enabling Dynamic Colors.";
            return;
        }
        Theme.applyWallpaperTheme(dark);
        syncDraft();
        statusText = dark ? "Wallpaper dark palette applied." : "Wallpaper light palette applied.";
    }

    function savePreset() {
        const name = presetName.trim();
        if (!name) {
            statusText = "Enter a name for this palette.";
            return;
        }
        const palette = {
            bg: String(draftBg),
            fg: String(draftFg),
            accent: String(draftAccent),
            accentComplementary: String(draftComplementary)
        };
        presetActionMode = "save";
        presetActionProcess.command = ["python3", Quickshell.shellDir + "/Scripts/theme/theme_preset_manager.py", "save", name, JSON.stringify(palette)];
        presetActionProcess.running = true;
    }

    function loadPreset(preset) {
        if (!preset)
            return;
        Theme.generateFromWallpaper = false;
        Theme.applyScheme({
            name: preset.name,
            bg: preset.bg,
            fg: preset.fg,
            accent: preset.accent,
            accentComplementary: preset.accentComplementary
        });
        syncDraft();
        statusText = "Applied " + preset.name + ".";
    }

    function deletePreset(id) {
        presetActionMode = "delete";
        presetActionProcess.command = ["python3", Quickshell.shellDir + "/Scripts/theme/theme_preset_manager.py", "delete", id];
        presetActionProcess.running = true;
    }

    function exportCurrentPalette(path) {
        const palette = {
            bg: String(draftBg),
            fg: String(draftFg),
            accent: String(draftAccent),
            accentComplementary: String(draftComplementary)
        };
        presetActionMode = "export";
        presetActionProcess.command = ["python3", Quickshell.shellDir + "/Scripts/theme/theme_preset_manager.py", "export", Theme.currentScheme || "Custom", JSON.stringify(palette), path];
        presetActionProcess.running = true;
    }

    function reloadPresets() {
        if (!presetListProcess.running)
            presetListProcess.running = true;
    }

    function updatePresets(raw) {
        try {
            const items = JSON.parse(raw || "[]");
            root.savedPresets = Array.isArray(items) ? items : [];
        } catch (error) {
            root.statusText = "Could not read saved palettes: " + error;
        }
    }

    Component.onCompleted: {
        syncDraft();
        reloadPresets();
    }

    Connections {
        target: Theme
        function onThemeApplied() {
            if (!bgDialog.visible && !fgDialog.visible && !accentDialog.visible && !complementDialog.visible)
                root.syncDraft();
        }
    }

    Process {
        id: presetListProcess
        command: ["python3", Quickshell.shellDir + "/Scripts/theme/theme_preset_manager.py", "list"]
        stdout: StdioCollector { id: presetListOutput }
        stderr: StdioCollector { id: presetListError }
        onExited: function(exitCode) {
            if (exitCode === 0)
                root.updatePresets(presetListOutput.text);
            else
                root.statusText = presetListError.text || "Could not load saved palettes.";
        }
    }

    property string presetActionMode: ""
    Process {
        id: presetActionProcess
        command: []
        stdout: StdioCollector { id: presetActionOutput }
        stderr: StdioCollector { id: presetActionError }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                if (root.presetActionMode === "delete")
                    root.statusText = "Palette deleted.";
                else if (root.presetActionMode === "export")
                    root.statusText = "Palette exported.";
                else if (root.presetActionMode === "import")
                    root.statusText = "Palette imported.";
                else
                    root.statusText = "Palette saved.";
                if (root.presetActionMode === "save")
                    root.presetName = "";
                if (root.presetActionMode !== "export")
                    root.reloadPresets();
            } else {
                root.statusText = presetActionError.text || "Palette operation failed.";
            }
        }
    }

    ColorDialog { id: bgDialog; title: "Background color"; selectedColor: root.draftBg; onAccepted: root.draftBg = selectedColor }
    ColorDialog { id: fgDialog; title: "Foreground color"; selectedColor: root.draftFg; onAccepted: root.draftFg = selectedColor }
    ColorDialog { id: accentDialog; title: "Accent color"; selectedColor: root.draftAccent; onAccepted: root.draftAccent = selectedColor }
    ColorDialog { id: complementDialog; title: "Complementary accent"; selectedColor: root.draftComplementary; onAccepted: root.draftComplementary = selectedColor }

    FileDialog {
        id: importPaletteDialog
        title: "Import Veyra palette"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Veyra palette (*.json)", "JSON files (*.json)"]
        onAccepted: {
            root.presetActionMode = "import";
            presetActionProcess.command = ["python3", Quickshell.shellDir + "/Scripts/theme/theme_preset_manager.py", "import", selectedFile.toLocalFile()];
            presetActionProcess.running = true;
        }
    }

    FileDialog {
        id: exportPaletteDialog
        title: "Export Veyra palette"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: ["Veyra palette (*.json)", "JSON files (*.json)"]
        onAccepted: root.exportCurrentPalette(selectedFile.toLocalFile())
    }

    AppGroup {
        title: "Wallpaper Palette"
        icon: "picture"
        SettingToggle {
            label: "Dynamic Colors"
            description: "Regenerate the palette when the wallpaper changes."
            checked: Theme.generateFromWallpaper
            onToggled: (checked) => {
                Theme.generateFromWallpaper = checked;
                Theme.saveScheme();
                if (checked && WallpaperManager.currentWallpaperPath !== "")
                    Theme.generateTheme(WallpaperManager.currentWallpaperPath);
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs
            ThemeButton {
                text: "Apply Dark Palette"
                enabled: Theme.wallpaperColors && Theme.wallpaperColors.dark
                onClicked: root.applyWallpaperVariant(true)
            }
            ThemeButton {
                text: "Apply Light Palette"
                enabled: Theme.wallpaperColors && Theme.wallpaperColors.light
                onClicked: root.applyWallpaperVariant(false)
            }
            Item { Layout.fillWidth: true }
            ThemeButton {
                text: "Regenerate"
                enabled: WallpaperManager.currentWallpaperPath !== ""
                onClicked: Theme.generateTheme(WallpaperManager.currentWallpaperPath)
            }
        }
        RowLayout {
            visible: Theme.wallpaperColors && Theme.wallpaperColors.dark && Theme.wallpaperColors.light
            Layout.fillWidth: true
            spacing: Constants.sizeSm
            Repeater {
                model: [
                    {label: "Dark", value: Theme.wallpaperColors ? Theme.wallpaperColors.dark : null},
                    {label: "Light", value: Theme.wallpaperColors ? Theme.wallpaperColors.light : null}
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: Constants.sizeSm
                    color: Theme.bgSecondary
                    border.color: Theme.border
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Repeater {
                            model: modelData.value ? [modelData.value.bg, modelData.value.fg, modelData.value.accent, modelData.value.accentComplementary] : []
                            delegate: Rectangle { required property string modelData; width: 23; height: 23; radius: 7; color: modelData; border.color: Theme.border }
                        }
                    }
                    ThemedText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.top: parent.top; anchors.topMargin: 4; text: modelData.label; customSize: 9; color: Theme.muted }
                }
            }
        }
    }

    AppGroup {
        title: "Custom Color Editor"
        icon: "palette"
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Constants.sizeSm
            rowSpacing: Constants.sizeSm
            Repeater {
                model: [
                    {label: "Background", color: root.draftBg, dialog: 0},
                    {label: "Foreground", color: root.draftFg, dialog: 1},
                    {label: "Accent", color: root.draftAccent, dialog: 2},
                    {label: "Complementary", color: root.draftComplementary, dialog: 3}
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: Constants.sizeSm
                    color: Theme.bgSecondary
                    border.color: Theme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Constants.sizeSm
                        Rectangle { width: 28; height: 28; radius: 8; color: modelData.color; border.color: Theme.border }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            ThemedText { text: modelData.label; customSize: 11; color: Theme.fg }
                            ThemedText { text: String(modelData.color); customSize: 9; color: Theme.muted }
                        }
                        ThemeButton {
                            text: "Edit"
                            onClicked: {
                                if (modelData.dialog === 0) bgDialog.open();
                                else if (modelData.dialog === 1) fgDialog.open();
                                else if (modelData.dialog === 2) accentDialog.open();
                                else complementDialog.open();
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 98
            radius: Constants.sizeMd
            color: root.draftBg
            border.color: Qt.rgba(root.draftAccent.r, root.draftAccent.g, root.draftAccent.b, 0.85)
            border.width: 2
            RowLayout {
                anchors.fill: parent
                anchors.margins: Constants.sizeMd
                ColumnLayout {
                    Layout.fillWidth: true
                    ThemedText { text: "Veyra Preview"; color: root.draftFg; customSize: 15; font.bold: true }
                    ThemedText { text: "Your custom palette in action"; color: Qt.rgba(root.draftFg.r, root.draftFg.g, root.draftFg.b, 0.65); customSize: 10 }
                }
                Rectangle {
                    radius: 9; color: root.draftAccent; implicitWidth: 76; implicitHeight: 32
                    ThemedText { anchors.centerIn: parent; text: "Accent"; color: root.draftBg; customSize: 10; font.bold: true }
                }
                Rectangle { width: 26; height: 26; radius: 13; color: root.draftComplementary }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            ThemeButton { text: "Apply Palette"; onClicked: root.applyDraft() }
            ThemeButton { text: "Discard Changes"; onClicked: root.syncDraft() }
            Item { Layout.fillWidth: true }
        }
    }

    AppGroup {
        title: "Saved Palettes"
        icon: "layers"
        RowLayout {
            Layout.fillWidth: true
            ThemeButton { text: "Import JSON"; onClicked: importPaletteDialog.open() }
            ThemeButton { text: "Export Current"; onClicked: exportPaletteDialog.open() }
            Item { Layout.fillWidth: true }
            ThemedText { text: root.savedPresets.length + " saved"; customSize: 9; color: Theme.muted }
        }
        RowLayout {
            Layout.fillWidth: true
            VeyraTextField {
                id: presetNameField
                Layout.fillWidth: true
                placeholderText: "Name this palette…"
                text: root.presetName
                onTextChanged: root.presetName = text
                color: Theme.fg
            }
            ThemeButton { text: "Save Palette"; enabled: root.presetName.trim() !== "" && !presetActionProcess.running; onClicked: root.savePreset() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs
            visible: root.savedPresets.length > 0
            Repeater {
                model: root.savedPresets
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: Constants.sizeSm
                    color: Theme.bgSecondary
                    border.color: Theme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Constants.sizeSm
                        Row {
                            spacing: 4
                            Repeater {
                                model: [modelData.bg, modelData.fg, modelData.accent, modelData.accentComplementary]
                                delegate: Rectangle { required property string modelData; width: 17; height: 17; radius: 6; color: modelData; border.color: Theme.border }
                            }
                        }
                        ThemedText { Layout.fillWidth: true; text: modelData.name; customSize: 11; color: Theme.fg; elide: Text.ElideRight }
                        ThemeButton { text: "Apply"; onClicked: root.loadPreset(modelData) }
                        ThemeButton {
                            text: "Delete"
                            onClicked: {
                                deleteConfirmDialog.presetId = modelData.id;
                                deleteConfirmDialog.presetName = modelData.name;
                                deleteConfirmDialog.open();
                            }
                        }
                    }
                }
            }
        }
        ThemedText {
            visible: root.savedPresets.length === 0
            text: "No saved palettes yet. Apply a custom palette and save it here."
            customSize: 10
            color: Theme.muted
        }
        ThemedText { text: root.statusText; visible: text !== ""; customSize: 10; color: Theme.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
    }

    Dialog {
        id: deleteConfirmDialog
        property string presetId: ""
        property string presetName: ""
        title: "Delete palette?"
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: root.deletePreset(presetId)
        contentItem: ThemedText { text: "Delete '" + deleteConfirmDialog.presetName + "'? This cannot be undone."; color: Theme.fg; customSize: 12; wrapMode: Text.Wrap }
    }
}
