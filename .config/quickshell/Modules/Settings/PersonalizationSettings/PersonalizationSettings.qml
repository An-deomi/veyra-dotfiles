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
    id: appearanceRoot

    pageTitle: "Appearance"
    pageDescription: "Manage system typography and application theme integrations."
    pageIcon: "color-palette"
    property var availableFonts: ["Geist"]
    property string currentFontName: SettingsService.fontFamily || "Geist"
    property int currentFontSize: Math.round(11 * SettingsService.fontScale) || 11

    property string customTemplateStatus: "Import a Noctalia community-template folder or a local template file. Imported templates start disabled."
    property string customTemplateActionMode: ""
    property string customTemplateActionOutput: ""
    property string customTemplateActionError: ""
    property string customTemplatePreviewText: ""

    function updateCustomTemplateList(jsonText) {
        try {
            const items = JSON.parse(jsonText.trim());
            if (!Array.isArray(items))
                throw new Error("Template list was not an array.");
            customTemplateModel.clear();
            for (let i = 0; i < items.length; i++) {
                const item = items[i];
                customTemplateModel.append({
                    templateId: String(item.id || ""),
                    templateName: String(item.name || item.id || "Custom template"),
                    templateEnabled: Boolean(item.enabled),
                    templateSummary: String(item.summary || "Custom color template")
                });
            }
        } catch (error) {
            customTemplateStatus = "Could not read the custom-template list: " + error;
        }
    }

    function reloadCustomTemplateList() {
        if (!customTemplateListProcess.running)
            customTemplateListProcess.running = true;
    }

    function runCustomTemplateAction(argsList, mode) {
        if (customTemplateActionProcess.running) {
            customTemplateStatus = "A template operation is already running. Please wait for it to finish.";
            return;
        }
        customTemplateActionMode = mode;
        customTemplateActionOutput = "";
        customTemplateActionError = "";
        if (mode === "import") {
            customTemplateStatus = customTemplateSourceField.text.trim().startsWith("http")
                ? "Downloading template from GitHub…"
                : "Importing template from your device…";
        } else if (mode === "preview") {
            customTemplateStatus = "Preparing preview…";
        } else if (mode === "remove") {
            customTemplateStatus = "Removing template and checking backups…";
        } else if (mode === "set-enabled") {
            customTemplateStatus = "Updating template preference…";
        }
        customTemplateActionProcess.command = ["python3", Quickshell.shellDir + "/Scripts/theme/custom_template_manager.py"].concat(argsList);
        customTemplateActionProcess.running = true;
    }

    function importCustomTemplate() {
        const source = customTemplateSourceField.text.trim();
        if (!source) {
            customTemplateStatus = "Enter a GitHub URL or choose a local file/folder first.";
            return;
        }
        let argsList = ["import", "--source", source];
        const name = customTemplateNameField.text.trim();
        const outputPath = customTemplateOutputField.text.trim();
        if (name)
            argsList.push("--name", name);
        if (outputPath)
            argsList.push("--output-path", outputPath);
        runCustomTemplateAction(argsList, "import");
    }

    function setCustomTemplateEnabled(templateId, enabled) {
        runCustomTemplateAction(["set-enabled", templateId, enabled ? "true" : "false"], "set-enabled");
    }

    function previewCustomTemplate(templateId) {
        runCustomTemplateAction(["preview", templateId], "preview");
    }

    function removeCustomTemplate(templateId) {
        runCustomTemplateAction(["remove", templateId], "remove");
    }

    function applyFont() {
        SettingsService.fontFamily = appearanceRoot.currentFontName;
        SettingsService.applyFont(appearanceRoot.currentFontName, appearanceRoot.currentFontSize);
    }

    Component.onCompleted: {
        if (appearanceRoot.availableFonts.indexOf(appearanceRoot.currentFontName) === -1) {
            let arr = appearanceRoot.availableFonts.slice();
            arr.unshift(appearanceRoot.currentFontName);
            appearanceRoot.availableFonts = arr;
        }
    }

    Connections {
        function onFontFamilyChanged() {
            if (appearanceRoot.currentFontName !== SettingsService.fontFamily)
                appearanceRoot.currentFontName = SettingsService.fontFamily || "Geist";

        }

        function onFontScaleChanged() {
            appearanceRoot.currentFontSize = Math.round(11 * SettingsService.fontScale) || 11;
        }

        target: SettingsService
    }

    Process {
        id: fetchFontsProc

        command: ["sh", "-c", "fc-list : family | cut -d, -f1 | sort -u"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (data) {
                    let lines = data.split('\n').map((x) => {
                        return x.trim();
                    }).filter((x) => {
                        return x !== "";
                    });
                    let arr = appearanceRoot.availableFonts.slice();
                    let changed = false;
                    lines.forEach((l) => {
                        if (arr.indexOf(l) === -1) {
                            arr.push(l);
                            changed = true;
                        }
                    });
                    if (arr.indexOf(appearanceRoot.currentFontName) === -1) {
                        arr.unshift(appearanceRoot.currentFontName);
                        changed = true;
                    }
                    if (changed)
                        appearanceRoot.availableFonts = arr;

                }
            }
        }

    }

    function refreshAppThemes() {
        appThemeRefreshTimer.restart();
    }

    Timer {
        id: appThemeRefreshTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (!appThemeRefreshProcess.running)
                appThemeRefreshProcess.running = true;
        }
    }

    Process {
        id: appThemeRefreshProcess
        command: ["python3", Quickshell.shellDir + "/Scripts/theme/apply_theme.py"]
    }

    ListModel {
        id: customTemplateModel
    }

    Process {
        id: customTemplateListProcess
        command: ["python3", Quickshell.shellDir + "/Scripts/theme/custom_template_manager.py", "list"]

        stdout: SplitParser {
            onRead: (data) => appearanceRoot.updateCustomTemplateList(data)
        }
        stderr: SplitParser {
            onRead: (data) => appearanceRoot.customTemplateStatus = data.trim()
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                appearanceRoot.customTemplateStatus = "Could not load custom templates. Check the Quickshell log.";
        }
        Component.onCompleted: running = true
    }

    Process {
        id: customTemplateActionProcess
        command: []

        stdout: SplitParser {
            onRead: (data) => appearanceRoot.customTemplateActionOutput += data + "\n"
        }
        stderr: SplitParser {
            onRead: (data) => appearanceRoot.customTemplateActionError += data + "\n"
        }
        onExited: function(exitCode, exitStatus) {
            const completedMode = appearanceRoot.customTemplateActionMode;
            const output = appearanceRoot.customTemplateActionOutput.trim();
            const error = appearanceRoot.customTemplateActionError.trim();
            if (exitCode === 0 && completedMode === "preview") {
                appearanceRoot.customTemplatePreviewText = output || "The manager returned an empty preview.";
                appearanceRoot.customTemplateStatus = "Preview ready. No app files have been written.";
                customTemplatePreviewDialog.open();
            } else if (exitCode === 0) {
                appearanceRoot.customTemplateStatus = output || "Template operation completed.";
            } else {
                appearanceRoot.customTemplateStatus = error || output || "Template operation failed. Check the Quickshell log.";
            }
            appearanceRoot.customTemplateActionOutput = "";
            appearanceRoot.customTemplateActionError = "";
            appearanceRoot.reloadCustomTemplateList();
            if (exitCode === 0 && (completedMode === "set-enabled" || completedMode === "remove"))
                appearanceRoot.refreshAppThemes();
        }
    }

    FileDialog {
        id: customTemplateFileDialog
        title: "Select a custom theme template file"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Template files (*.toml *.css *.conf *.ini *.json *.yaml *.yml *.txt)", "All files (*)"]
        onAccepted: customTemplateSourceField.text = selectedFile.toString()
    }

    FolderDialog {
        id: customTemplateFolderDialog
        title: "Select a Noctalia template folder"
        onAccepted: customTemplateSourceField.text = selectedFolder.toString()
    }


    Dialog {
        id: customTemplatePreviewDialog
        title: "Generated theme preview"
        modal: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(720, Math.max(320, appearanceRoot.width - 48))
        height: Math.min(560, Math.max(300, appearanceRoot.height - 48))
        standardButtons: Dialog.Close

        contentItem: ScrollView {
            id: customTemplatePreviewScroll
            clip: true
            contentWidth: availableWidth
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Text {
                width: customTemplatePreviewScroll.availableWidth
                text: appearanceRoot.customTemplatePreviewText
                color: Theme.fg
                wrapMode: Text.WrapAnywhere
                textFormat: Text.PlainText
                font.family: "monospace"
                font.pixelSize: 11
            }
        }
    }

    AppGroup {
        title: "Dynamic Theme Appliers"
        icon: "palette"
        badge: "10 controls"
        showDividers: false

        AppGroup {
            title: "Desktop & Appearance"
            icon: "color-palette"
            badge: "5"
            columns: 2
            flat: true
            collapsible: false
            showDividers: false

            SettingToggle {
                label: "GTK"
                description: "Update generated GTK 3 and GTK 4 colors."
                checked: SettingsService.dynamicThemeGtkEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeGtkEnabled) {
                        SettingsService.dynamicThemeGtkEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

            SettingToggle {
                label: "KDE Color Scheme"
                description: "Update the generated KDE color scheme."
                checked: SettingsService.dynamicThemeKColorSchemeEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeKColorSchemeEnabled) {
                        SettingsService.dynamicThemeKColorSchemeEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

            SettingToggle {
                label: "Qt Applications"
                description: "Update the qt6ct palette and color settings."
                checked: SettingsService.dynamicThemeQtEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeQtEnabled) {
                        SettingsService.dynamicThemeQtEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

            SettingToggle {
                label: "Hyprland"
                description: "Update generated compositor colors."
                checked: SettingsService.dynamicThemeHyprlandEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeHyprlandEnabled) {
                        SettingsService.dynamicThemeHyprlandEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

            SettingToggle {
                label: "Shell SVG Assets"
                description: "Update supported SVG assets with palette colors."
                checked: SettingsService.dynamicThemeSvgAssetsEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeSvgAssetsEnabled) {
                        SettingsService.dynamicThemeSvgAssetsEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

        }

        AppGroup {
            title: "Terminal & Developer"
            icon: "terminal"
            badge: "5"
            columns: 2
            flat: true
            collapsible: false
            showDividers: false

            SettingToggle {
                label: "Kitty Terminal"
                description: "Update the generated Kitty terminal palette."
                checked: SettingsService.dynamicThemeKittyEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeKittyEnabled) {
                        SettingsService.dynamicThemeKittyEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

            SettingToggle {
                label: "Neovim"
                description: "Update Veyra's generated Neovim theme."
                checked: SettingsService.dynamicThemeNeovimEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeNeovimEnabled) {
                        SettingsService.dynamicThemeNeovimEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

            SettingToggle {
                label: "Starship"
                description: "Update generated prompt colors in Starship's config."
                checked: SettingsService.dynamicThemeStarshipEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeStarshipEnabled) {
                        SettingsService.dynamicThemeStarshipEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

            SettingToggle {
                label: "btop"
                description: "Update the generated btop theme."
                checked: SettingsService.dynamicThemeBtopEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeBtopEnabled) {
                        SettingsService.dynamicThemeBtopEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

            SettingToggle {
                label: "lazygit"
                description: "Update the generated lazygit theme section."
                checked: SettingsService.dynamicThemeLazygitEnabled
                onCheckedChanged: {
                    if (checked !== SettingsService.dynamicThemeLazygitEnabled) {
                        SettingsService.dynamicThemeLazygitEnabled = checked;
                        appearanceRoot.refreshAppThemes();
                    }
                }
            }

        }
    }

    AppGroup {
        title: "App Themes"
        icon: "color-palette"
        badge: "6 integrations"
        columns: 2
        collapsible: true
        expanded: false

        SettingToggle {
            label: "Zen Browser"
            description: "Apply Matugen CSS to detected Zen profiles"
            checked: SettingsService.appThemeZenBrowserEnabled
            onCheckedChanged: {
                if (checked !== SettingsService.appThemeZenBrowserEnabled) {
                    SettingsService.appThemeZenBrowserEnabled = checked;
                    appearanceRoot.refreshAppThemes();
                }
            }
        }

        SettingToggle {
            label: "Spotify / Spicetify"
            description: "Generate Comfy and Colorful palettes and apply Spicetify"
            checked: SettingsService.appThemeSpicetifyEnabled
            onCheckedChanged: {
                if (checked !== SettingsService.appThemeSpicetifyEnabled) {
                    SettingsService.appThemeSpicetifyEnabled = checked;
                    appearanceRoot.refreshAppThemes();
                }
            }
        }

        SettingToggle {
            label: "Heroic Launcher"
            description: "Generate Matugen CSS; select the theme in Heroic once"
            checked: SettingsService.appThemeHeroicEnabled
            onCheckedChanged: {
                if (checked !== SettingsService.appThemeHeroicEnabled) {
                    SettingsService.appThemeHeroicEnabled = checked;
                    appearanceRoot.refreshAppThemes();
                }
            }
        }

        SettingToggle {
            label: "Papirus Icons"
            description: "Match folder colors and dark/light variant to the palette"
            checked: SettingsService.appThemePapirusEnabled
            onCheckedChanged: {
                if (checked !== SettingsService.appThemePapirusEnabled) {
                    SettingsService.appThemePapirusEnabled = checked;
                    appearanceRoot.refreshAppThemes();
                }
            }
        }

        SettingToggle {
            label: "Telegram Desktop"
            description: "Generate a Veyra theme file; import/select it in Telegram"
            checked: SettingsService.appThemeTelegramEnabled
            onCheckedChanged: {
                if (checked !== SettingsService.appThemeTelegramEnabled) {
                    SettingsService.appThemeTelegramEnabled = checked;
                    appearanceRoot.refreshAppThemes();
                }
            }
        }

        SettingToggle {
            label: "VSCodium"
            description: "Match NoctaliaTheme UI colors to the Veyra wallpaper palette"
            checked: SettingsService.appThemeVSCodiumEnabled
            onCheckedChanged: {
                if (checked !== SettingsService.appThemeVSCodiumEnabled) {
                    SettingsService.appThemeVSCodiumEnabled = checked;
                    appearanceRoot.refreshAppThemes();
                }
            }
        }
    }

    AppGroup {
        title: "Custom App Templates"
        icon: "code"
        badge: "GitHub + local"
        showDividers: false

        ThemedText {
            text: "Import Noctalia community templates or a file from your device. Leave the name blank to detect it from the template manifest or filename. Imports start disabled; previewing never writes app files."
            customSize: 11
            color: Theme.muted
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            VeyraTextField {
                id: customTemplateSourceField
                Layout.fillWidth: true
                enabled: !customTemplateActionProcess.running
                placeholderText: "GitHub template-folder URL or local path"
                selectByMouse: true
                color: Theme.fg
                background: Rectangle {
                    implicitHeight: 36
                    color: Theme.isDark
                        ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                        : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                    radius: Constants.sizeSm
                    border.width: customTemplateSourceField.activeFocus ? 1.5 : 1
                    border.color: customTemplateSourceField.activeFocus ? Theme.accent : (customTemplateSourceField.hovered ? Theme.muted : Theme.border)
                }
            }

            ThemeButton {
                text: "File"
                enabled: !customTemplateActionProcess.running
                onClicked: customTemplateFileDialog.open()
            }

            ThemeButton {
                text: "Folder"
                enabled: !customTemplateActionProcess.running
                onClicked: customTemplateFolderDialog.open()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            VeyraTextField {
                id: customTemplateNameField
                Layout.fillWidth: true
                enabled: !customTemplateActionProcess.running
                placeholderText: "Name (optional — auto-detected)"
                selectByMouse: true
                color: Theme.fg
                background: Rectangle {
                    implicitHeight: 36
                    color: Theme.isDark
                        ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                        : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                    radius: Constants.sizeSm
                    border.width: customTemplateNameField.activeFocus ? 1.5 : 1
                    border.color: customTemplateNameField.activeFocus ? Theme.accent : (customTemplateNameField.hovered ? Theme.muted : Theme.border)
                }
            }

            VeyraTextField {
                id: customTemplateOutputField
                Layout.fillWidth: true
                enabled: !customTemplateActionProcess.running
                placeholderText: "Output path (standalone file only)"
                selectByMouse: true
                color: Theme.fg
                background: Rectangle {
                    implicitHeight: 36
                    color: Theme.isDark
                        ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                        : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                    radius: Constants.sizeSm
                    border.width: customTemplateOutputField.activeFocus ? 1.5 : 1
                    border.color: customTemplateOutputField.activeFocus ? Theme.accent : (customTemplateOutputField.hovered ? Theme.muted : Theme.border)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            BusyIndicator {
                visible: customTemplateActionProcess.running
                    && appearanceRoot.customTemplateActionMode === "import"
                running: visible
                implicitWidth: 26
                implicitHeight: 26
                Accessible.name: "Importing custom template"
            }

            ThemeButton {
                text: customTemplateActionProcess.running && appearanceRoot.customTemplateActionMode === "import"
                    ? (customTemplateSourceField.text.trim().startsWith("http") ? "Downloading…" : "Importing…")
                    : "Import Template"
                enabled: !customTemplateActionProcess.running
                onClicked: appearanceRoot.importCustomTemplate()
            }

            Item { Layout.fillWidth: true }

            ThemedText {
                text: customTemplateModel.count + " imported"
                customSize: 10
                color: Theme.muted
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs
            visible: customTemplateModel.count > 0

            Repeater {
                model: customTemplateModel
                delegate: RowLayout {
                    required property string templateId
                    required property string templateName
                    required property bool templateEnabled
                    required property string templateSummary
                    Layout.fillWidth: true
                    spacing: Constants.sizeXs

                    SettingToggle {
                        Layout.fillWidth: true
                        enabled: !customTemplateActionProcess.running
                        label: templateName
                        description: templateSummary
                        checked: templateEnabled
                        onToggled: (checked) => appearanceRoot.setCustomTemplateEnabled(templateId, checked)
                    }

                    ThemeButton {
                        text: "Preview"
                        enabled: !customTemplateActionProcess.running
                        onClicked: appearanceRoot.previewCustomTemplate(templateId)
                    }

                    ThemeButton {
                        text: "Remove"
                        enabled: !customTemplateActionProcess.running
                        onClicked: appearanceRoot.removeCustomTemplate(templateId)
                    }
                }
            }
        }

        Text {
            text: appearanceRoot.customTemplateStatus
            color: Theme.muted
            font.pixelSize: 10
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }

    AppGroup {
        title: "System Fonts"
        icon: "font"

        ThemedSelect {
            id: fontSelect

            function updateSelection() {
                for (let i = 0; i < appearanceRoot.availableFonts.length; i++) {
                    if (appearanceRoot.availableFonts[i] === appearanceRoot.currentFontName) {
                        fontSelect.currentIndex = i;
                        return ;
                    }
                }
                fontSelect.currentIndex = 0;
            }

            label: "System Font"
            description: "Global font for GTK, Qt and Shell"
            comboWidth: 260
            searchable: true
            model: appearanceRoot.availableFonts
            Component.onCompleted: updateSelection()
            onModelChanged: updateSelection()
            onActivated: (index) => {
                let newFont = model[index];
                if (appearanceRoot.currentFontName !== newFont) {
                    appearanceRoot.currentFontName = newFont;
                    appearanceRoot.applyFont();
                }
            }

            Connections {
                function onCurrentFontNameChanged() {
                    fontSelect.updateSelection();
                }

                target: appearanceRoot
            }

        }

        SettingSpinBox {
            label: "Global Font Scale"
            description: "Scales fonts across Quickshell, GTK and Qt"
            from: 0.7
            to: 2.5
            stepSize: 0.05
            value: SettingsService.fontScale
            suffix: "x"
            decimals: 2
            onMoved: (val) => {
                let newSize = Math.round(11 * val);
                if (appearanceRoot.currentFontSize !== newSize) {
                    appearanceRoot.currentFontSize = newSize;
                    SettingsService.fontScale = val;
                    appearanceRoot.applyFont();
                } else {
                    SettingsService.fontScale = val;
                }
            }
        }

    }


    AppGroup {
        title: "Desktop Music Visualizer"
        icon: "music"

        SettingToggle {
            label: "Enable Desktop Visualizer"
            description: "Show animated bars over the desktop while music is playing."
            checked: SettingsService.desktopCavaEnabled
            onToggled: (checked) => {
                SettingsService.desktopCavaEnabled = checked;
                SettingsService.saveSettings();
            }
        }

        SettingSpinBox {
            label: "Visualizer Height"
            description: "Height of the desktop visualizer area."
            from: 50
            to: 180
            stepSize: 10
            value: SettingsService.desktopCavaHeight
            defaultValue: 92
            suffix: " px"
            onMoved: (val) => {
                SettingsService.desktopCavaHeight = Math.round(val);
                SettingsService.saveSettings();
            }
        }

        SettingSpinBox {
            label: "Visualizer Width"
            description: "Maximum width of the waveform, centered on the desktop."
            from: 300
            to: 1600
            stepSize: 50
            value: SettingsService.desktopCavaWidth
            defaultValue: 720
            suffix: " px"
            onMoved: (val) => {
                SettingsService.desktopCavaWidth = Math.round(val);
                SettingsService.saveSettings();
            }
        }

        SettingSpinBox {
            label: "Bar Count"
            description: "Fewer bars are simpler; more bars show more audio detail."
            from: 12
            to: 72
            stepSize: 6
            value: SettingsService.desktopCavaBarCount
            defaultValue: 36
            onMoved: (val) => {
                SettingsService.desktopCavaBarCount = Math.round(val);
                SettingsService.saveSettings();
            }
        }

        SettingSpinBox {
            label: "Bar Spacing"
            description: "Space between bars. Larger gaps may be limited for compact layouts."
            from: 0
            to: 12
            stepSize: 1
            value: SettingsService.desktopCavaSpacing
            defaultValue: 4
            suffix: " px"
            onMoved: (val) => {
                SettingsService.desktopCavaSpacing = Math.round(val);
                SettingsService.saveSettings();
            }
        }

        SettingSegmented {
            label: "Color Mode"
            description: "Match your dynamic wallpaper colors or use one theme color."
            model: [
                { "text": "Gradient", "value": "gradient" },
                { "text": "Accent", "value": "accent" },
                { "text": "Complement", "value": "complementary" }
            ]
            currentValue: SettingsService.desktopCavaColorMode
            onActivated: (value) => {
                SettingsService.desktopCavaColorMode = value;
                SettingsService.saveSettings();
            }
        }
    }

}
