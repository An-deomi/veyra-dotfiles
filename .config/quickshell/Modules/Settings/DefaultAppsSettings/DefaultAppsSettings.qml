import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    property var appInfo: ({ apps: [], choices: ({}), defaults: ({}), terminals: [] })
    property string statusMessage: "Discovering installed desktop applications…"
    property string pendingDefaultRole: ""

    function storedFor(role) {
        switch (role) {
        case "terminal": return SettingsService.defaultTerminalCommand;
        case "browser": return SettingsService.defaultBrowserAppId;
        case "coding": return SettingsService.defaultCodingAppId;
        case "fileManager": return SettingsService.defaultFileManagerAppId;
        case "textEditor": return SettingsService.defaultTextEditorAppId;
        case "imageViewer": return SettingsService.defaultImageViewerAppId;
        case "videoPlayer": return SettingsService.defaultVideoPlayerAppId;
        case "musicPlayer": return SettingsService.defaultMusicPlayerAppId;
        case "pdfViewer": return SettingsService.defaultPdfViewerAppId;
        }
        return "";
    }

    function currentFor(role) {
        const stored = storedFor(role) || "";
        if (stored !== "")
            return stored;
        if (role === "terminal")
            return "kitty";
        if (role === "coding") {
            const coding = (appInfo.choices || ({})).coding || [];
            if (coding.indexOf("codium.desktop") !== -1)
                return "codium.desktop";
            return coding.length ? coding[0] : "__none__";
        }
        const defaults = appInfo.defaults || ({});
        if (defaults[role])
            return defaults[role];
        const choices = (appInfo.choices || ({}))[role] || [];
        return choices.length ? choices[0] : "__none__";
    }

    function optionsFor(role) {
        if (role === "terminal") {
            const result = [];
            const terms = appInfo.terminals || [];
            for (let i = 0; i < terms.length; i++)
                result.push(terms[i].command);
            const currentTerminal = currentFor(role);
            if (currentTerminal && result.indexOf(currentTerminal) === -1)
                result.push(currentTerminal);
            return result.length ? result : ["__none__"];
        }
        const available = ["__system__"];
        const filtered = ((appInfo.choices || ({}))[role] || []).slice();
        for (let i = 0; i < filtered.length; i++) {
            if (available.indexOf(filtered[i]) === -1)
                available.push(filtered[i]);
        }
        const current = currentFor(role);
        if (current && current !== "__none__" && available.indexOf(current) === -1)
            available.push(current);
        return available.length ? available : ["__none__"];
    }

    function namesFor(role) {
        const result = ({
            "__none__": "No compatible application found",
            "__system__": "Follow the Linux system default"
        });
        if (role === "terminal") {
            const terms = appInfo.terminals || [];
            for (let i = 0; i < terms.length; i++)
                result[terms[i].command] = terms[i].name + " (" + terms[i].command + ")";
            return result;
        }
        const apps = appInfo.apps || [];
        for (let i = 0; i < apps.length; i++)
            result[apps[i].id] = apps[i].name;
        return result;
    }

    function chooseApp(role, value) {
        if (!value || value === "__none__")
            return;
        if (value === "__system__" && role !== "terminal" && role !== "coding") {
            switch (role) {
            case "browser": SettingsService.defaultBrowserAppId = value; break;
            case "fileManager": SettingsService.defaultFileManagerAppId = value; break;
            case "textEditor": SettingsService.defaultTextEditorAppId = value; break;
            case "imageViewer": SettingsService.defaultImageViewerAppId = value; break;
            case "videoPlayer": SettingsService.defaultVideoPlayerAppId = value; break;
            case "musicPlayer": SettingsService.defaultMusicPlayerAppId = value; break;
            case "pdfViewer": SettingsService.defaultPdfViewerAppId = value; break;
            }
            SettingsService.saveSettings();
            statusMessage = "Veyra will follow the Linux system default for " + role + ".";
            return;
        }
        switch (role) {
        case "terminal": SettingsService.defaultTerminalCommand = value; break;
        case "browser": SettingsService.defaultBrowserAppId = value; break;
        case "coding": SettingsService.defaultCodingAppId = value; break;
        case "fileManager": SettingsService.defaultFileManagerAppId = value; break;
        case "textEditor": SettingsService.defaultTextEditorAppId = value; break;
        case "imageViewer": SettingsService.defaultImageViewerAppId = value; break;
        case "videoPlayer": SettingsService.defaultVideoPlayerAppId = value; break;
        case "musicPlayer": SettingsService.defaultMusicPlayerAppId = value; break;
        case "pdfViewer": SettingsService.defaultPdfViewerAppId = value; break;
        }
        SettingsService.saveSettings();

        if (role === "terminal" || role === "coding") {
            statusMessage = "Saved Veyra preference. It will be used by the shell shortcuts and launcher.";
            return;
        }
        pendingDefaultRole = role;
        if (applyDefaultProc.running)
            applyDefaultProc.running = false;
        applyDefaultProc.command = ["python3", Quickshell.shellDir + "/Scripts/system/default_apps.py", "set-default", role, value];
        applyDefaultProc.running = true;
        statusMessage = "Applying " + role + " as the Linux desktop default…";
    }

    Process {
        id: appListProc
        command: ["python3", Quickshell.shellDir + "/Scripts/system/default_apps.py", "list"]
        running: true

        stdout: StdioCollector {
            id: appListOutput
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.statusMessage = "Could not read installed desktop applications. Check the helper script and terminal log.";
                return;
            }
            try {
                root.appInfo = JSON.parse(appListOutput.text.trim());
                root.statusMessage = root.appInfo.apps.length + " desktop applications detected. Choices are saved automatically.";
            } catch (e) {
                root.statusMessage = "Could not parse the installed application list.";
                console.error("Veyra Default Apps: " + e);
            }
        }
    }

    Process {
        id: applyDefaultProc
        stdout: StdioCollector { id: applyDefaultOutput }
        stderr: StdioCollector { id: applyDefaultError }
        onExited: (exitCode) => {
            if (exitCode === 0)
                root.statusMessage = "Updated the Linux desktop default for " + root.pendingDefaultRole + ".";
            else
                root.statusMessage = "Preference saved, but the system default could not be applied: " + applyDefaultError.text.trim();
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 112
        radius: Constants.sizeLg
        color: Theme.bgSecondary
        border.width: 1
        border.color: Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.margins: Constants.sizeLg
            spacing: Constants.sizeMd

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignVCenter
                radius: Constants.sizeMd
                color: Theme.bgAccent

                SvgIcon {
                    anchors.centerIn: parent
                    icon: "apps"
                    iconSize: Constants.sizeXl
                    iconColor: Theme.accent
                    flat: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Constants.size2Xs

                ThemedText {
                    Layout.fillWidth: true
                    text: "Your apps, your workflow"
                    customSize: Constants.sizeLg
                    font.weight: Font.DemiBold
                    color: Theme.fg
                    elide: Text.ElideRight
                }

                ThemedText {
                    Layout.fillWidth: true
                    text: "Choose what opens links, projects, folders, documents, and media. Changes save automatically."
                    customSize: Constants.sizeXs + 2
                    color: Theme.muted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: root.appInfo.apps && root.appInfo.apps.length > 0
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                radius: height / 2
                implicitWidth: appCountLabel.implicitWidth + Constants.sizeMd * 2
                implicitHeight: Constants.sizeXl
                color: Theme.bgTertiary
                border.width: 1
                border.color: Theme.border

                ThemedText {
                    id: appCountLabel
                    anchors.centerIn: parent
                    text: root.appInfo.apps.length + " apps"
                    customSize: Constants.sizeXs + 1
                    color: Theme.muted
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    AppGroup {
        collapsible: true
        title: "Launch & Work"
        icon: "terminal"
        badge: "4"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            DefaultAppSelect {
                pageRoot: root
                role: "terminal"
                label: "Terminal"
                iconName: "terminal"
                description: "Super+T and commands launched inside a terminal."
            }

            DefaultAppSelect {
                pageRoot: root
                role: "coding"
                label: "Coding app / IDE"
                iconName: "code"
                description: "Your editor or IDE, including Super+Enter."
            }

            DefaultAppSelect {
                pageRoot: root
                role: "browser"
                label: "Web browser"
                iconName: "apps"
                description: "Web links, HTTP/HTTPS, and Super+W."
            }

            DefaultAppSelect {
                pageRoot: root
                role: "fileManager"
                label: "File manager"
                iconName: "apps"
                description: "Folders and the Super+E shortcut."
            }
        }
    }

    AppGroup {
        collapsible: true
        title: "Documents & Images"
        icon: "picture"
        badge: "3"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            DefaultAppSelect {
                pageRoot: root
                role: "textEditor"
                label: "Text editor"
                iconName: "code"
                description: "Plain-text files and notes."
            }

            DefaultAppSelect {
                pageRoot: root
                role: "pdfViewer"
                label: "PDF viewer"
                iconName: "code"
                description: "PDF documents opened from the file manager or browser."
            }

            DefaultAppSelect {
                pageRoot: root
                role: "imageViewer"
                label: "Image viewer"
                iconName: "picture"
                description: "PNG, JPEG, WebP, and other common images."
            }
        }
    }

    AppGroup {
        collapsible: true
        title: "Audio & Video"
        icon: "music"
        badge: "2"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            DefaultAppSelect {
                pageRoot: root
                role: "musicPlayer"
                label: "Music player"
                iconName: "music"
                description: "Default app for common audio files. Separate from the MPRIS control setting."
            }

            DefaultAppSelect {
                pageRoot: root
                role: "videoPlayer"
                label: "Video player"
                iconName: "monitor"
                description: "Movies, clips, and other common video files."
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: statusLabel.implicitHeight + Constants.sizeMd * 2
        radius: Constants.sizeMd
        color: Theme.bgTertiary
        border.width: 1
        border.color: Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.margins: Constants.sizeMd
            spacing: Constants.sizeSm

            SvgIcon {
                Layout.alignment: Qt.AlignTop
                icon: root.statusMessage.toLowerCase().indexOf("could not") !== -1 || root.statusMessage.toLowerCase().indexOf("failed") !== -1 ? "warning" : "info"
                iconSize: Constants.sizeMd
                iconColor: root.statusMessage.toLowerCase().indexOf("could not") !== -1 || root.statusMessage.toLowerCase().indexOf("failed") !== -1 ? Theme.accentComplementary : Theme.accent
                flat: true
            }

            ThemedText {
                id: statusLabel
                Layout.fillWidth: true
                text: root.statusMessage
                color: Theme.muted
                customSize: Constants.sizeXs + 2
                wrapMode: Text.WordWrap
            }
        }
    }
}
