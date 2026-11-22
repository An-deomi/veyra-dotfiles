import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Launcher.Components

Item {
    id: root

    property var widget: null
    property string searchText: ""
    property string selectedCategory: "All"
    readonly property var categories: ["All", "Favorites", "Recent", "Internet", "Games", "Development", "Multimedia", "Office", "Graphics", "System", "Utilities"]
    property var allApps: []
    property var filteredApps: []
    property alias initialFocusItem: searchField
    property int maxVisibleItems: 8
    readonly property bool isSearching: searchField.text.trim() !== ""
    readonly property int currentResultsCount: root.filteredApps ? root.filteredApps.length : 0
    readonly property int targetVisibleItems: {
        if (!isSearching)
            return maxVisibleItems;

        if (currentResultsCount === 0)
            return maxVisibleItems;

        return Math.min(currentResultsCount, maxVisibleItems);
    }
    property int visibleItems: targetVisibleItems
    property int preferredContentWidth: 700
    readonly property int searchBarHeight: Constants.size4Xl
    readonly property int categoryBarHeight: 34
    readonly property int itemHeight: 44
    readonly property int listSpacing: Constants.sizeXs
    readonly property int layoutSpacing: Constants.sizeSm
    readonly property int maxListHeight: (maxVisibleItems * itemHeight) + Math.max(0, (maxVisibleItems - 1) * listSpacing)
    readonly property int baseListHeight: (targetVisibleItems * itemHeight) + Math.max(0, (targetVisibleItems - 1) * listSpacing)
    readonly property int expandedExtraHeight: {
        if (typeof appsView !== "undefined" && appsView && appsView.expandedIndex >= 0 && root.filteredApps && appsView.expandedIndex < root.filteredApps.length) {
            let app = root.filteredApps[appsView.expandedIndex];
            if (app && app.actions && app.actions.length > 0) {
                let n = app.actions.length;
                return (n * 34) + Math.max(0, (n - 1) * 4) + Constants.sizeXs;
            }
        }
        return 0;
    }
    readonly property int visibleListHeight: {
        if (!isSearching)
            return maxListHeight + Math.min(expandedExtraHeight, 200);

        if (currentResultsCount === 0)
            return maxListHeight;

        let needed = baseListHeight + expandedExtraHeight;
        let maxAllowed = maxListHeight + Math.min(expandedExtraHeight, 200);
        return Math.min(needed, maxAllowed);
    }

    function appMatchesCategory(app) {
        if (root.selectedCategory === "All")
            return true;
        const pinned = SettingsService.pinnedLauncherApps || [];
        if (root.selectedCategory === "Favorites")
            return app.id && pinned.indexOf(app.id) !== -1;
        if (root.selectedCategory === "Recent") {
            const recent = SettingsService.recentLauncherApps || [];
            return app.id && recent.indexOf(app.id) !== -1;
        }

        const appCategories = app.categories || [];
        const groups = {
            "Internet": ["Network", "WebBrowser", "Email", "InstantMessaging", "Chat", "RemoteAccess"],
            "Games": ["Game"],
            "Development": ["Development", "IDE", "Building", "Debugger", "RevisionControl"],
            "Multimedia": ["AudioVideo", "Audio", "Video", "Player", "Recorder", "DiscBurning"],
            "Office": ["Office", "WordProcessor", "Spreadsheet", "Presentation", "Calendar"],
            "Graphics": ["Graphics", "2DGraphics", "3DGraphics", "Photography", "RasterGraphics", "VectorGraphics"],
            "System": ["System", "Settings", "Monitor", "FileManager", "TerminalEmulator", "FileSystem"],
            "Utilities": ["Utility", "Accessories", "TextEditor", "Archiving", "Compression", "Calculator", "Security"]
        };
        const accepted = groups[root.selectedCategory] || [];
        return accepted.some(function(category) {
            return appCategories.indexOf(category) !== -1;
        });
    }

    property var emojiList: []

    function evalMath(expr) {
        const src = expr.replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/");
        if (!/^[0-9+\-*\/().%^]+$/.test(src))
            return null;
        if (!/[+*\/%^]/.test(src) && !/.-/.test(src))
            return null;
        let pos = 0;
        function peek() { return src[pos]; }
        function parseExpr() {
            let v = parseTerm();
            while (peek() === "+" || peek() === "-") {
                const op = src[pos++];
                const r = parseTerm();
                v = op === "+" ? v + r : v - r;
            }
            return v;
        }
        function parseTerm() {
            let v = parseUnary();
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = src[pos++];
                const r = parseUnary();
                v = op === "*" ? v * r : (op === "/" ? v / r : v % r);
            }
            return v;
        }
        function parseUnary() {
            if (peek() === "-") { pos++; return -parseUnary(); }
            if (peek() === "+") { pos++; return parseUnary(); }
            return parsePow();
        }
        function parsePow() {
            const base = parseAtom();
            if (peek() === "^") { pos++; return Math.pow(base, parseUnary()); }
            return base;
        }
        function parseAtom() {
            if (peek() === "(") {
                pos++;
                const v = parseExpr();
                if (peek() !== ")") throw new Error("paren");
                pos++;
                return v;
            }
            const m = /^[0-9]*\.?[0-9]+|^[0-9]+\.?/.exec(src.slice(pos));
            if (!m) throw new Error("num");
            pos += m[0].length;
            return parseFloat(m[0]);
        }
        try {
            const v = parseExpr();
            if (pos !== src.length || !isFinite(v))
                return null;
            return parseFloat(v.toPrecision(12));
        } catch (e) {
            return null;
        }
    }

    function filterApps(query) {
        const normalized = (query || "").trim().toLowerCase();
        root.searchText = normalized;
        const pinned = SettingsService.pinnedLauncherApps || [];
        const recent = SettingsService.recentLauncherApps || [];
        const tokens = normalized.split(/\s+/).filter(function(token) {
            return token.length > 0;
        });

        function words(text) {
            return text.split(/[^a-z0-9]+/).filter(function(word) { return word.length > 0; });
        }

        function recentOrder(id) {
            const idx = id ? recent.indexOf(id) : -1;
            return idx < 0 ? 9999 : idx;
        }

        function searchScore(app) {
            if (!normalized)
                return 100;

            const name = (app.name || "").toLowerCase().trim();
            const genericName = (app.genericName || "").toLowerCase().trim();
            const comment = (app.comment || "").toLowerCase();
            const categoryText = (app.categories || []).join(" ").toLowerCase();
            const keywordList = (app.keywords || []).map(function(k) { return k.toLowerCase(); });
            const keywordText = keywordList.join(" ");
            const nameWords = words(name);
            const genericWords = words(genericName);
            const acronym = nameWords.map(function(word) { return word[0]; }).join("");

            if (name === normalized)
                return 0;
            if (name.startsWith(normalized))
                return 1;
            if (nameWords.some(function(word) { return word.startsWith(normalized); }))
                return 2;
            if (normalized.length >= 2 && acronym.startsWith(normalized))
                return 2.5;
            if (tokens.every(function(token) { return name.includes(token); }))
                return 3;
            if (genericName === normalized)
                return 4;
            if (genericName.startsWith(normalized))
                return 5;
            if (genericWords.some(function(word) { return word.startsWith(normalized); }))
                return 6;
            if (tokens.every(function(token) { return genericName.includes(token); }))
                return 7;
            if (name.includes(normalized))
                return 8;
            if (genericName.includes(normalized))
                return 9;
            if (keywordList.some(function(k) {
                return k.startsWith(normalized) || words(k).some(function(w) { return w.startsWith(normalized); });
            }))
                return 9.5;
            if (tokens.every(function(token) { return keywordText.includes(token); }))
                return 9.6;
            if (tokens.every(function(token) { return comment.includes(token); }))
                return 10;
            if (tokens.every(function(token) { return categoryText.includes(token); }))
                return 11;
            return 12;
        }

        let scored = [];
        for (let i = 0; i < root.allApps.length; i++) {
            const app = root.allApps[i];
            const searchable = [app.name || "", app.comment || "", app.genericName || "", (app.categories || []).join(" "), (app.keywords || []).join(" ")].join(" ").toLowerCase();
            const matchesQuery = !normalized || tokens.every(function(token) {
                return searchable.includes(token);
            });
            if (root.appMatchesCategory(app) && matchesQuery)
                scored.push({ app: app, score: searchScore(app) });
        }

        scored.sort(function(a, b) {
            if (a.score !== b.score)
                return a.score - b.score;

            if (root.selectedCategory === "Recent") {
                const aOrder = recentOrder(a.app.id);
                const bOrder = recentOrder(b.app.id);
                if (aOrder !== bOrder)
                    return aOrder - bOrder;
            }

            const aPinned = a.app.id && pinned.indexOf(a.app.id) !== -1 ? 0 : 1;
            const bPinned = b.app.id && pinned.indexOf(b.app.id) !== -1 ? 0 : 1;
            if (aPinned !== bPinned)
                return aPinned - bPinned;

            if (normalized) {
                const aRecent = recentOrder(a.app.id);
                const bRecent = recentOrder(b.app.id);
                if (aRecent !== bRecent)
                    return aRecent - bRecent;
            }

            const aName = (a.app.name || "").toLowerCase();
            const bName = (b.app.name || "").toLowerCase();
            return aName < bName ? -1 : (aName > bName ? 1 : 0);
        });

        let results = scored.map(function(item) { return item.app; });
        const raw = (query || "").trim();

        function specialRow(id, name, comment, icon, exec, terminal) {
            return { id: id, name: name, exec: exec, icon: icon, terminal: terminal || false,
                     actions: [], categories: [], comment: comment, genericName: "", keywords: [] };
        }
        function shQuote(str) {
            return '"' + str.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
        }

        if (raw.startsWith(">")) {
            const inTerm = raw.startsWith(">>");
            const cmd = raw.slice(inTerm ? 2 : 1).trim();
            results = [];
            if (cmd)
                results.push(specialRow("__run__", (inTerm ? "Run in terminal: " : "Run: ") + cmd,
                    "Enter to run", "utilities-terminal", cmd, inTerm));
        } else if (raw.startsWith(":")) {
            const q = raw.slice(1).trim().toLowerCase().replace(/\s+/g, "_");
            results = [];
            if (root.emojiList.length === 0 && !loadEmojiProc.running)
                loadEmojiProc.running = true;
            if (q.length > 0) {
                let hits = [];
                for (let i = 0; i < root.emojiList.length; i++) {
                    const item = root.emojiList[i];
                    const hay = item.n + " " + (item.a || []).join(" ");
                    if (hay.indexOf(q) === -1)
                        continue;
                    const names = [item.n].concat(item.a || []);
                    let rank = 3;
                    for (let k = 0; k < names.length; k++) {
                        const nm = names[k];
                        const r = nm === q ? 0 : (nm.startsWith(q) ? 1 : (nm.indexOf("_" + q) !== -1 ? 2 : 3));
                        if (r < rank)
                            rank = r;
                    }
                    hits.push({ item: item, rank: rank });
                }
                hits.sort(function(a, b) { return a.rank !== b.rank ? a.rank - b.rank : a.item.n.length - b.item.n.length; });
                for (let j = 0; j < hits.length && j < 60; j++) {
                    const it = hits[j].item;
                    results.push(specialRow("__emoji__" + it.e, it.e + "   " + it.n.replace(/_/g, " "),
                        "Enter to copy", "", "wl-copy -- " + it.e));
                }
            }
        } else if (raw === "cb" || raw.startsWith("cb ")) {
            results = [
                specialRow("__clipboard__", "Open Clipboard History",
                    "Enter to open Veyra Clipboard", "edit-paste",
                    "qs ipc call widgets open clipboard")
            ];
        } else if (raw.startsWith("!")) {
            const spaceIdx = raw.indexOf(" ");
            const prefix = (spaceIdx === -1 ? raw.slice(1) : raw.slice(1, spaceIdx)).toLowerCase();
            const term = spaceIdx === -1 ? "" : raw.slice(spaceIdx + 1).trim();
            const engines = {
                "g":   { name: "Google",     url: "https://www.google.com/search?q=" },
                "yt":  { name: "YouTube",    url: "https://www.youtube.com/results?search_query=" },
                "ddg": { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
                "gh":  { name: "GitHub",     url: "https://github.com/search?q=" },
                "aw":  { name: "Arch Wiki",  url: "https://wiki.archlinux.org/index.php?search=" }
            };
            results = [];
            if (engines[prefix]) {
                const eng = engines[prefix];
                results.push(specialRow("__web_" + prefix + "__",
                    term ? ("Search " + eng.name + " for \"" + term + "\"") : ("Type a query to search " + eng.name + "..."),
                    "!" + prefix + " · Enter to open in browser", "system-search",
                    term ? ("xdg-open " + shQuote(eng.url + encodeURIComponent(term))) : ""));
            }
        } else if (raw) {
            const calc = evalMath(raw);
            if (calc !== null)
                results.unshift(specialRow("__calc__", "= " + calc, "Enter to copy",
                    "accessories-calculator", "wl-copy -- " + calc));
            if (results.length === 0)
                results.push(specialRow("__web__", "Search the web for \"" + raw + "\"",
                    "Enter to open in browser", "system-search",
                    "xdg-open " + shQuote("https://duckduckgo.com/?q=" + encodeURIComponent(raw))));
        }

        root.filteredApps = results;
        if (appsView) {
            appsView.expandedIndex = -1;
            if (root.filteredApps.length > 0)
                appsView.currentIndex = 0;
            else
                appsView.currentIndex = -1;
        }
    }

    function handleKeyPress(event, fromSearch) {
        let currentDelegate = appsView.currentItem;
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            if (currentDelegate && currentDelegate.isExpanded && currentDelegate.currentActionIndex < currentDelegate.actionCount - 1) {
                currentDelegate.currentActionIndex++;
                event.accepted = true;
            } else if (appsView.count > 0) {
                appsView.expandedIndex = -1;
                appsView.currentIndex = (appsView.currentIndex + 1) % appsView.count;
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            if (currentDelegate && currentDelegate.isExpanded && currentDelegate.currentActionIndex >= 0) {
                currentDelegate.currentActionIndex--;
                event.accepted = true;
            } else if (appsView.count > 0) {
                appsView.expandedIndex = -1;
                appsView.currentIndex = (appsView.currentIndex - 1 + appsView.count) % appsView.count;
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Right) {
            if (currentDelegate && currentDelegate.hasActions && !currentDelegate.isExpanded) {
                appsView.expandedIndex = appsView.currentIndex;
                currentDelegate.currentActionIndex = 0;
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Left) {
            if (currentDelegate && currentDelegate.isExpanded) {
                appsView.expandedIndex = -1;
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            let idx = appsView.currentIndex >= 0 ? appsView.currentIndex : 0;
            if (root.filteredApps.length > idx) {
                if (currentDelegate && currentDelegate.isExpanded && currentDelegate.currentActionIndex >= 0) {
                    let action = root.filteredApps[idx].actions[currentDelegate.currentActionIndex];
                    launchApp(action.exec, false, root.filteredApps[idx].id);
                } else {
                    let app = root.filteredApps[idx];
                    launchApp(app.exec, app.terminal, app.id);
                }
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Escape) {
            if (root.widget && typeof root.widget.close === "function")
                root.widget.close();
            else if (root.widget && root.widget.isOpen !== undefined)
                root.widget.isOpen = false;
            else
                AppState.activeWidget = "";
            event.accepted = true;
        }
    }

    function launchApp(exec, terminal, appId) {
        if (!exec)
            return ;
        if (appId && !appId.startsWith("__"))
            SettingsService.recordLauncherLaunch(appId);
        let command = [];
        const defaultsHelper = Quickshell.shellDir + "/Scripts/system/default_apps.py";
        if (appId === "__run__") {
            // Preserve raw command text so shell quoting and substitutions survive.
            command = ["python3", defaultsHelper, terminal ? "run-shell-in-terminal" : "run-shell", exec];
        } else {
            let re = /"((?:[^"\\]|\\.)*)"|'([^']*)'|(\S+)/g;
            let m;
            while ((m = re.exec(exec)) !== null) {
                let arg = m[1] !== undefined ? m[1].replace(/\\(.)/g, "$1")
                        : (m[2] !== undefined ? m[2] : m[3]);
                if (!arg.startsWith('%'))
                    command.push(arg);
            }
            if (terminal)
                command = ["python3", defaultsHelper, "run-in-terminal"].concat(command);
        }

        appLauncher.running = false;
        appLauncher.command = command;
        appLauncher.startDetached();
        AppState.closeAllWidgets();
        if (root.widget && root.widget.close !== undefined)
            root.widget.close();
        else if (root.widget && root.widget.isOpen !== undefined)
            root.widget.isOpen = false;
    }

    function resetLauncher() {
        if (appsView)
            appsView.expandedIndex = -1;

        searchField.text = "";
        if (AppState.launcherApps && AppState.launcherApps.length > 0) {
            root.allApps = AppState.launcherApps;
            filterApps("");
        }
        if (!loadAppsProc.running)
            loadAppsProc.running = true;
        searchField.forceActiveFocus();
    }

    implicitWidth: preferredContentWidth
    implicitHeight: searchBarHeight + categoryBarHeight + (layoutSpacing * 2) + visibleListHeight
    width: parent && parent.width > 0 ? parent.width : implicitWidth
    height: parent && parent.height > 0 ? parent.height : implicitHeight
    Component.onCompleted: {
        resetLauncher();
    }

    Connections {
        target: SettingsService
        function onPinnedLauncherAppsChanged() {
            if (root.allApps.length > 0)
                root.filterApps(searchField.text);
        }
    }

    Process {
        id: loadEmojiProc

        command: ["python3", Quickshell.shellDir + "/Modules/Launcher/scripts/get_emoji.py"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    root.emojiList = JSON.parse(emojiOutput.text);
                    filterApps(searchField.text);
                } catch (e) {
                    console.error("Error parsing emoji JSON: " + e);
                }
            }
        }

        stdout: StdioCollector {
            id: emojiOutput
        }

    }

    Process {
        id: loadAppsProc

        command: ["python3", Quickshell.shellDir + "/Modules/Launcher/scripts/get_apps.py"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    let parsed = JSON.parse(appFetcherOutput.text);
                    AppState.launcherApps = parsed;
                    root.allApps = parsed;
                    filterApps(searchField.text);
                } catch (e) {
                    console.error("Error parsing apps JSON: " + e);
                }
            }
        }

        stdout: StdioCollector {
            id: appFetcherOutput
        }

    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.layoutSpacing

        Item {
            id: topSearchContainer

            Layout.fillWidth: true
            Layout.preferredHeight: SettingsService.barConvexMode ? 0 : Constants.size4Xl
            visible: !SettingsService.barConvexMode
        }

        Flickable {
            id: categoryFlickable
            Layout.fillWidth: true
            Layout.preferredHeight: root.categoryBarHeight
            clip: true
            contentWidth: categoryRow.implicitWidth
            contentHeight: height
            interactive: contentWidth > width
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: categoryRow
                height: parent.height
                width: implicitWidth
                spacing: Constants.sizeXs

                Repeater {
                    model: root.categories
                    delegate: Rectangle {
                        width: categoryLabel.implicitWidth + Constants.sizeLg * 2
                        height: 30
                        y: (categoryRow.height - height) / 2
                        radius: Constants.sizeMd
                        color: root.selectedCategory === modelData ? Theme.bgSecondary : "transparent"
                        border.width: root.selectedCategory === modelData ? 1 : 0
                        border.color: Theme.border

                        Text {
                            id: categoryLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: root.selectedCategory === modelData ? Theme.accent : Theme.fg
                            font.pixelSize: 12
                            font.bold: root.selectedCategory === modelData
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedCategory = modelData;
                                root.filterApps(searchField.text);
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Constants.animFast
                            }
                        }
                    }
                }
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
                opacity: (root.filteredApps.length === 0 && (root.isSearching || root.selectedCategory !== "All")) ? 1 : 0
                text: root.isSearching ? "No applications found" : (root.selectedCategory === "Favorites" ? "No pinned apps yet" : (root.selectedCategory === "Recent" ? "No recently launched apps yet" : "No apps in this category"))
                isAnimating: visible

                Behavior on opacity {
                    NumberAnimation {
                        duration: Constants.animFast
                        easing.type: Easing.OutCubic
                    }

                }

            }

            ListView {
                id: appsView

                property int expandedIndex: -1

                onExpandedIndexChanged: {
                    if (expandedIndex >= 0)
                        Qt.callLater(function() {
                        appsView.positionViewAtIndex(expandedIndex, ListView.Contain);
                    });

                }
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredApps
                spacing: root.listSpacing
                currentIndex: -1
                highlightResizeDuration: 0
                highlightMoveDuration: Constants.animFast
                highlightFollowsCurrentItem: true
                visible: root.filteredApps.length > 0
                Keys.onPressed: function(event) {
                    root.handleKeyPress(event, false);
                }

                highlight: Item {
                    width: appsView.width
                    height: 44
                    z: 1

                    Rectangle {
                        anchors.fill: parent
                        radius: Constants.sizeLg
                        color: Theme.bgSecondary
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

                delegate: LauncherItemDelegate {
                    modelData: model.modelData
                    isCurrent: appsView.currentIndex === index
                    isExpanded: appsView.expandedIndex === index
                    isPinned: (SettingsService.pinnedLauncherApps || []).indexOf(modelData.id) !== -1
                    onToggleExpanded: {
                        if (appsView.expandedIndex === index) {
                            appsView.expandedIndex = -1;
                        } else {
                            appsView.expandedIndex = index;
                            appsView.currentIndex = index;
                        }
                    }
                    onLaunchRequested: function(execCmd, terminalFlag, appId) {
                        root.launchApp(execCmd, terminalFlag, appId);
                    }
                    onPinToggleRequested: function(appId) {
                        SettingsService.toggleLauncherPin(appId);
                        root.filterApps(searchField.text);
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                    active: true
                }

            }

        }

        Item {
            id: bottomSearchContainer

            Layout.fillWidth: true
            Layout.preferredHeight: SettingsService.barConvexMode ? 40 : 0
            visible: SettingsService.barConvexMode
        }

    }

    ThemedSearchBar {
        id: searchField

        parent: SettingsService.barConvexMode ? bottomSearchContainer : topSearchContainer
        anchors.fill: parent
        preferredHeight: Constants.size4Xl
        placeholderText: "Search apps, =math, :emoji, !g, !yt, cb, >cmd..."
        onSearchRequested: (text) => {
            return root.filterApps(text);
        }
        customSize: Constants.sizeMd
        textField.Keys.onPressed: function(event) {
            root.handleKeyPress(event, true);
        }
    }

    Process {
        id: appLauncher
    }

}
