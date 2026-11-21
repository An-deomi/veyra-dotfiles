import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Services
pragma Singleton

Item {
    id: root

    property alias model: clipboardModel
    property alias filteredModel: filteredModel
    property bool isDeleting: false
    property string currentSearchQuery: ""
    property string currentFilter: "all"
    property var pinnedEntries: []
    property bool pinsLoaded: false
    property bool pinsLoadFailed: false
    property string pinStatus: ""
    property string pendingPinId: ""
    property string pendingPinPreview: ""
    property string pendingPinFullLine: ""
    readonly property string pinsPath: XdgPaths.stateDir + "/clipboard_pins.json"
    readonly property string legacyPinsPath: XdgPaths.cacheDir + "/clipboard_pins.json"
    readonly property int maxPinnedEntries: 40
    readonly property int maxPinnedTextLength: 16000

    function refresh() {
        loadClipboardProc.running = true;
    }

    function showPinStatus(message) {
        pinStatus = message;
        pinStatusTimer.restart();
    }

    function isPinned(itemId) {
        let idText = String(itemId === undefined || itemId === null ? "" : itemId);
        for (let i = 0; i < pinnedEntries.length; i++) {
            if (String(pinnedEntries[i].itemId) === idText)
                return true;
        }
        return false;
    }

    function syncModel(listModel, sourceArray) {
        let sourceIds = {};
        for (let i = 0; i < sourceArray.length; i++)
            sourceIds[String(sourceArray[i].itemId)] = true;

        for (let i = listModel.count - 1; i >= 0; i--) {
            if (!sourceIds[String(listModel.get(i).itemId)])
                listModel.remove(i);
        }

        for (let i = 0; i < sourceArray.length; i++) {
            let src = sourceArray[i];
            if (i >= listModel.count) {
                listModel.append(src);
                continue;
            }

            if (String(listModel.get(i).itemId) !== String(src.itemId)) {
                let foundIdx = -1;
                for (let j = i + 1; j < listModel.count; j++) {
                    if (String(listModel.get(j).itemId) === String(src.itemId)) {
                        foundIdx = j;
                        break;
                    }
                }
                if (foundIdx !== -1)
                    listModel.move(foundIdx, i, 1);
                else {
                    listModel.insert(i, src);
                    continue;
                }
            }

            let dest = listModel.get(i);
            let keys = Object.keys(src);
            for (let k = 0; k < keys.length; k++) {
                let key = keys[k];
                if (dest[key] !== src[key])
                    listModel.setProperty(i, key, src[key]);
            }
        }
    }

    function filterClipboard(query, filterKey) {
        if (query !== undefined && query !== null)
            currentSearchQuery = String(query);
        if (filterKey !== undefined && filterKey !== null)
            currentFilter = ["all", "pinned", "text", "images"].indexOf(String(filterKey)) !== -1 ? String(filterKey) : "all";

        let matchedItems = [];
        let queryLower = currentSearchQuery.toLowerCase();

        if (currentFilter === "pinned") {
            for (let p = 0; p < pinnedEntries.length; p++) {
                let pin = pinnedEntries[p];
                let preview = String(pin.preview !== undefined ? pin.preview : pin.text || "");
                let fullText = String(pin.text !== undefined ? pin.text : preview);
                if (queryLower !== "" && fullText.toLowerCase().indexOf(queryLower) === -1 && preview.toLowerCase().indexOf(queryLower) === -1)
                    continue;
                matchedItems.push({
                    "itemId": String(pin.itemId),
                    "text": preview,
                    "fullLine": "",
                    "isImage": false,
                    "isPinned": true,
                    "isPinnedSnapshot": true,
                    "pinnedText": fullText
                });
            }
        } else {
            for (let i = 0; i < clipboardModel.count; i++) {
                let item = clipboardModel.get(i);
                let isImage = item.isImage !== undefined ? item.isImage : false;
                if (currentFilter === "text" && isImage)
                    continue;
                if (currentFilter === "images" && !isImage)
                    continue;

                let itemText = String(item.text || "");
                let textMatches = !isImage && (queryLower === "" || itemText.toLowerCase().indexOf(queryLower) !== -1);
                let imageMatches = isImage && (queryLower === "" || itemText.toLowerCase().indexOf(queryLower) !== -1);
                if (textMatches || imageMatches) {
                    matchedItems.push({
                        "itemId": String(item.itemId),
                        "text": itemText,
                        "fullLine": String(item.fullLine || ""),
                        "isImage": isImage,
                        "isPinned": root.isPinned(item.itemId),
                        "isPinnedSnapshot": false,
                        "pinnedText": ""
                    });
                }
            }
        }

        syncModel(filteredModel, matchedItems);
    }

    function copyItem(itemId, closeWidgetCallback) {
        if (!itemId)
            return;
        copyProc.command = ["bash", "-c", "cliphist decode \"$1\" | wl-copy", "veyra-clipboard", String(itemId)];
        copyProc.startDetached();
        if (closeWidgetCallback)
            closeWidgetCallback();
    }

    function copyEntry(item, closeWidgetCallback) {
        if (!item)
            return;
        if (item.isPinnedSnapshot === true) {
            copyPinnedText(String(item.pinnedText !== undefined ? item.pinnedText : item.text || ""), closeWidgetCallback);
            return;
        }
        copyItem(item.itemId, closeWidgetCallback);
    }

    function copyPinnedText(text, closeWidgetCallback) {
        pinnedCopyProc.running = false;
        pinnedCopyProc.stdinEnabled = true;
        pinnedCopyProc.command = ["wl-copy"];
        pinnedCopyProc.running = true;
        pinnedCopyProc.write(String(text));
        pinnedCopyProc.stdinEnabled = false;
        if (closeWidgetCallback)
            closeWidgetCallback();
    }

    function togglePin(itemId, preview, fullLine, isImage) {
        let idText = String(itemId === undefined || itemId === null ? "" : itemId);
        if (!idText || isImage)
            return;

        for (let i = 0; i < pinnedEntries.length; i++) {
            if (String(pinnedEntries[i].itemId) === idText) {
                let nextPins = pinnedEntries.slice();
                nextPins.splice(i, 1);
                pinnedEntries = nextPins;
                savePins();
                filterClipboard(currentSearchQuery, currentFilter);
                showPinStatus("Removed from pinned snippets");
                return;
            }
        }

        if (pinnedEntries.length >= maxPinnedEntries) {
            showPinStatus("Pin limit reached (" + maxPinnedEntries + ")");
            return;
        }
        if (pinDecodeProc.running) {
            showPinStatus("One snippet is already being pinned");
            return;
        }

        pendingPinId = idText;
        pendingPinPreview = String(preview || "");
        pendingPinFullLine = String(fullLine || "");
        pinDecodeProc.command = ["cliphist", "decode", idText];
        pinDecodeProc.running = true;
    }

    function clearPinnedItems() {
        pinnedEntries = [];
        savePins();
        filterClipboard(currentSearchQuery, currentFilter);
        showPinStatus("Pinned snippets cleared");
    }

    function savePins() {
        pinsSaveTimer.restart();
    }

    function deleteItem(index, fullLine) {
        if (index < 0 || index >= filteredModel.count)
            return;
        if (!fullLine)
            return;

        isDeleting = true;
        deletingResetTimer.restart();
        filteredModel.remove(index);
        for (let i = 0; i < clipboardModel.count; i++) {
            if (clipboardModel.get(i).fullLine === fullLine) {
                clipboardModel.remove(i);
                break;
            }
        }
        deleteProc.command = ["bash", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "veyra-clipboard", String(fullLine)];
        deleteProc.startDetached();
    }

    function clearHistory() {
        if (!pinsLoaded) {
            showPinStatus("Pinned snippets are still loading; try again shortly");
            return;
        }
        if (pinsLoadFailed) {
            showPinStatus("History was not cleared because pinned snippets could not be verified");
            return;
        }
        if (clipboardModel.count === 0)
            return;

        // Clear unpinned history only. Keep the source entries for pinned snippets
        // so they remain visible in All as well as in the independent Pinned view.
        isDeleting = true;
        deletingResetTimer.restart();
        clipboardModel.clear();
        if (currentFilter !== "pinned")
            filteredModel.clear();
        clearProc.running = false;
        clearProc.stdinEnabled = true;
        clearProc.running = true;
        let ids = [];
        for (let i = 0; i < pinnedEntries.length; i++)
            ids.push({ "itemId": String(pinnedEntries[i].itemId) });
        clearProc.write(JSON.stringify(ids));
        clearProc.stdinEnabled = false;
    }

    ListModel {
        id: clipboardModel
    }

    ListModel {
        id: filteredModel
    }

    Process {
        id: pinsLoader
        command: ["bash", "-c", XdgPaths.migrateCatSnippet, "veyra-pins-loader", root.pinsPath, root.legacyPinsPath, "[]"]
        running: true
        stdout: StdioCollector { id: pinsOutput }
        stderr: StdioCollector { id: pinsError }
        onExited: function(exitCode) {
            let loaded = [];
            let loadFailed = false;
            if (exitCode === 0) {
                try {
                    let parsed = JSON.parse(pinsOutput.text || "[]");
                    if (!Array.isArray(parsed))
                        throw new Error("pin file is not an array");
                    for (let i = 0; i < parsed.length && loaded.length < root.maxPinnedEntries; i++) {
                        let item = parsed[i];
                        if (item && item.itemId !== undefined && typeof item.text === "string") {
                            loaded.push({
                                "itemId": String(item.itemId),
                                "text": item.text.slice(0, root.maxPinnedTextLength),
                                "preview": String(item.preview !== undefined ? item.preview : item.text).slice(0, 240),
                                "pinnedAt": Number(item.pinnedAt || 0)
                            });
                        } else {
                            loadFailed = true;
                            break;
                        }
                    }
                } catch (e) {
                    loadFailed = true;
                }
            } else {
                loadFailed = true;
            }
            root.pinnedEntries = loaded;
            root.pinsLoadFailed = loadFailed;
            root.pinsLoaded = true;
            if (loadFailed)
                root.showPinStatus("Pinned snippets could not be verified; clean is disabled for safety");
            root.filterClipboard(root.currentSearchQuery, root.currentFilter);
        }
    }

    Process {
        id: pinDecodeProc
        stdout: StdioCollector { id: pinDecodeOutput }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.showPinStatus("Could not pin this clipboard item");
                root.pendingPinId = "";
                root.pendingPinPreview = "";
                root.pendingPinFullLine = "";
                return;
            }
            let decoded = String(pinDecodeOutput.text !== undefined ? pinDecodeOutput.text : "");
            if (decoded.length > root.maxPinnedTextLength) {
                root.showPinStatus("That snippet is too large to pin (max 16,000 characters)");
                root.pendingPinId = "";
                root.pendingPinPreview = "";
                root.pendingPinFullLine = "";
                return;
            }
            let nextPins = root.pinnedEntries.slice();
            nextPins.unshift({
                "itemId": root.pendingPinId,
                "text": decoded,
                "preview": root.pendingPinPreview.slice(0, 240),
                "pinnedAt": Date.now()
            });
            root.pinnedEntries = nextPins;
            root.savePins();
            root.filterClipboard(root.currentSearchQuery, root.currentFilter);
            root.showPinStatus("Pinned snippet saved");
            root.pendingPinId = "";
            root.pendingPinPreview = "";
            root.pendingPinFullLine = "";
        }
    }

    Process {
        id: pinSaveProc
        stdinEnabled: true
        command: ["python3", Quickshell.shellDir + "/Modules/Clipboard/scripts/save_pins.py", root.pinsPath]
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.showPinStatus("Could not save pinned snippets");
        }
    }

    Process {
        id: pinnedCopyProc
        stdinEnabled: true
    }

    Timer {
        id: pinsSaveTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (pinSaveProc.running) {
                pinsSaveTimer.restart();
                return;
            }
            pinSaveProc.stdinEnabled = true;
            pinSaveProc.command = ["python3", Quickshell.shellDir + "/Modules/Clipboard/scripts/save_pins.py", root.pinsPath];
            pinSaveProc.running = true;
            pinSaveProc.write(JSON.stringify(root.pinnedEntries));
            pinSaveProc.stdinEnabled = false;
        }
    }

    Process {
        id: loadClipboardProc
        command: ["cliphist", "list"]
        onExited: function(exitCode) {
            if (exitCode !== 0)
                return;
            clipboardModel.clear();
            let output = clipboardOutput.text.trim();
            if (output === "") {
                root.filterClipboard(root.currentSearchQuery, root.currentFilter);
                return;
            }
            let lines = output.split("\n");
            if (SettingsService.clipboardMaxItems > 0)
                lines = lines.slice(0, SettingsService.clipboardMaxItems);
            let imageIds = [];
            lines.forEach(function(line) {
                if (line.trim() === "")
                    return;
                let parts = line.split("\t");
                if (parts.length >= 2) {
                    let itemId = String(parts[0]);
                    let text = parts.slice(1).join("\t");
                    let isImage = text.startsWith("[[ binary data") && text.includes("]]" );
                    if (isImage)
                        imageIds.push(itemId);
                    clipboardModel.append({
                        "itemId": itemId,
                        "text": text,
                        "fullLine": line,
                        "isImage": isImage,
                        "isPinned": root.isPinned(itemId),
                        "isPinnedSnapshot": false,
                        "pinnedText": ""
                    });
                }
            });
            if (imageIds.length > 0) {
                // Ids must be decimal cliphist ids; the decoder also enforces
                // this and writes into a private cache dir (0700/0600).
                let numericIds = imageIds.filter((itemId) => /^\d+$/.test(itemId));
                if (numericIds.length > 0) {
                    decodeImagesProc.command = [
                        "python3",
                        Quickshell.shellDir + "/Modules/Clipboard/scripts/decode_images.py",
                        XdgPaths.cacheDir + "/clipboard-images"
                    ].concat(numericIds);
                    decodeImagesProc.running = true;
                } else {
                    root.filterClipboard(root.currentSearchQuery, root.currentFilter);
                }
            } else {
                root.filterClipboard(root.currentSearchQuery, root.currentFilter);
            }
        }
        stdout: StdioCollector { id: clipboardOutput }
    }

    Process {
        id: decodeImagesProc
        onExited: function(exitCode) {
            root.filterClipboard(root.currentSearchQuery, root.currentFilter);
        }
    }

    Process { id: copyProc }
    Process { id: deleteProc }

    Process {
        id: clearProc
        stdinEnabled: true
        command: ["python3", Quickshell.shellDir + "/Modules/Clipboard/scripts/clear_unpinned.py"]
        stdout: StdioCollector { id: clearOutput }
        stderr: StdioCollector { id: clearError }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                let message = String(clearOutput.text || "").trim();
                root.showPinStatus(message || "Unpinned clipboard history cleared; pinned items kept");
                loadClipboardProc.running = true;
            } else {
                let detail = String(clearError.text || "").trim();
                root.showPinStatus("Could not safely clear history; pinned items were kept");
                if (detail !== "")
                    console.warn("Clipboard cleanup failed:", detail);
                loadClipboardProc.running = true;
            }
        }
    }

    Timer {
        id: deletingResetTimer
        interval: Constants.animNormal * 2 + 50
        repeat: false
        onTriggered: root.isDeleting = false
    }

    Timer {
        id: pinStatusTimer
        interval: 2600
        repeat: false
        onTriggered: root.pinStatus = ""
    }
}
