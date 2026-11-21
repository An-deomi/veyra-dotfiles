import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string recentsPath: XdgPaths.cacheDir + "/emoji_recent.json"
    readonly property var categories: [
        { label: "All", group: "" },
        { label: "😀", group: "Smileys & Emotion" },
        { label: "👋", group: "People & Body" },
        { label: "🐻", group: "Animals & Nature" },
        { label: "🍔", group: "Food & Drink" },
        { label: "✈️", group: "Travel & Places" },
        { label: "⚽", group: "Activities" },
        { label: "💡", group: "Objects" },
        { label: "🔣", group: "Symbols" },
        { label: "🏁", group: "Flags" }
    ]
    property var theme: ({})
    property var all: []
    property var byChar: ({})
    property var recents: []
    property string query: ""
    property var results: []
    property int cat: 0
    property real shown: 0
    property int topGap: 52
    readonly property color panelColor: {
        const c = Qt.color(col("bg", "#090b09"));
        return Qt.rgba(c.r, c.g, c.b, col("bgOpacity", 0.9));
    }

    function col(key, fallback) {
        return theme[key] !== undefined ? theme[key] : fallback;
    }

    function rebuild() {
        const q = query.trim().toLowerCase().replace(/\s+/g, "_");
        let out = [];
        if (q === "") {
            if (cat === 0) {
                const seen = {};
                for (let i = 0; i < recents.length; i++) {
                    const it = byChar[recents[i]];
                    if (it) {
                        out.push(it);
                        seen[it.e] = true;
                    }
                }
                for (let j = 0; j < all.length; j++) {
                    if (!seen[all[j].e])
                        out.push(all[j]);
                }
            } else {
                const g = categories[cat].group;
                for (let j = 0; j < all.length; j++) {
                    if (all[j].g === g)
                        out.push(all[j]);
                }
            }
        } else {
            let hits = [];
            for (let i = 0; i < all.length; i++) {
                const item = all[i];
                const names = [item.n].concat(item.a || []);
                let rank = 4;
                for (let k = 0; k < names.length; k++) {
                    const nm = names[k];
                    const r = nm === q ? 0 : (nm.startsWith(q) ? 1 : (nm.indexOf("_" + q) !== -1 ? 2 : (nm.indexOf(q) !== -1 ? 3 : 4)));
                    if (r < rank)
                        rank = r;
                }
                if (rank < 4)
                    hits.push({ item: item, rank: rank });
            }
            hits.sort(function(a, b) {
                return a.rank !== b.rank ? a.rank - b.rank : a.item.n.length - b.item.n.length;
            });
            out = hits.map(function(h) { return h.item; });
        }
        results = out;
    }

    function setCat(i) {
        cat = (i + categories.length) % categories.length;
        rebuild();
        grid.currentIndex = 0;
        grid.positionViewAtBeginning();
    }

    function choose(item) {
        if (!item)
            return;
        Quickshell.execDetached(["wl-copy", "--", item.e]);
        let list = [item.e];
        for (let i = 0; i < recents.length; i++) {
            if (recents[i] !== item.e)
                list.push(recents[i]);
        }
        list = list.slice(0, 27);
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", JSON.stringify(list), recentsPath]);
        Qt.quit();
    }

    FileView {
        path: XdgPaths.stateDir + "/colorscheme.json"
        printErrors: false
        onLoaded: {
            try {
                root.theme = JSON.parse(text());
            } catch (e) {
            }
        }
    }

    FileView {
        path: root.recentsPath
        printErrors: false
        onLoaded: {
            try {
                root.recents = JSON.parse(text());
            } catch (e) {
            }
            root.rebuild();
        }
    }

    Process {
        running: true
        command: ["python3", Quickshell.shellDir + "/get_emoji.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    let m = {};
                    for (let i = 0; i < data.length; i++)
                        m[data[i].e] = data[i];
                    root.byChar = m;
                    root.all = data;
                    root.rebuild();
                } catch (e) {
                    console.error("emoji data: " + e);
                }
            }
        }
    }

    NumberAnimation {
        id: showAnim

        target: root
        property: "shown"
        from: 0
        to: 1
        duration: 160
        easing.type: Easing.OutCubic
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "emoji-picker"

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }

        Rectangle {
            id: card

            width: 408
            height: 380
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.topGap - (1 - root.shown) * 14
            opacity: root.shown
            radius: 22
            color: root.panelColor
            border.color: root.col("border", "#1af0f3f1")
            border.width: 1
            Component.onCompleted: {
                input.forceActiveFocus();
                showAnim.start();
            }

            MouseArea {
                anchors.fill: parent
            }

            Rectangle {
                id: searchBox

                x: 16
                y: 16
                width: parent.width - 32
                height: 40
                radius: 12
                color: root.col("bgSecondary", "#0f9dd88f")
                border.width: input.activeFocus ? 1.5 : 1
                border.color: input.activeFocus ? root.col("accent", "#79cc65") : root.col("border", "#1af0f3f1")

                TextInput {
                    id: input

                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.col("fg", "#f0f3f1")
                    selectionColor: root.col("accent", "#79cc65")
                    font.pixelSize: 15
                    focus: true
                    onTextChanged: {
                        root.query = text;
                        if (text !== "" && root.cat !== 0)
                            root.cat = 0;
                        root.rebuild();
                        grid.currentIndex = 0;
                        grid.positionViewAtBeginning();
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            Qt.quit();
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.results.length > 0)
                                root.choose(root.results[grid.currentIndex]);
                        } else if (event.key === Qt.Key_Tab) {
                            root.setCat(root.cat + 1);
                        } else if (event.key === Qt.Key_Backtab) {
                            root.setCat(root.cat - 1);
                        } else if (event.key === Qt.Key_Down) {
                            grid.moveCurrentIndexDown();
                        } else if (event.key === Qt.Key_Up) {
                            grid.moveCurrentIndexUp();
                        } else if (event.key === Qt.Key_Left) {
                            grid.moveCurrentIndexLeft();
                        } else if (event.key === Qt.Key_Right) {
                            grid.moveCurrentIndexRight();
                        } else {
                            return ;
                        }
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === ""
                    text: "Search emoji..."
                    color: root.col("muted", "#66f0f3f1")
                    font.pixelSize: 15
                }

            }

            Row {
                id: tabs

                x: 16
                y: searchBox.y + searchBox.height + 8
                width: parent.width - 32
                height: 30

                Repeater {
                    model: root.categories

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: tabs.width / root.categories.length
                        height: tabs.height

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 9
                            color: (root.cat === parent.index && root.query === "") ? root.col("bgAccent", "#2679cc65") : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            font.pixelSize: parent.index === 0 ? 12 : 16
                            font.family: parent.index === 0 ? Qt.application.font.family : "Noto Color Emoji"
                            color: root.col("fg", "#f0f3f1")
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.setCat(parent.index)
                        }

                    }

                }

            }

            GridView {
                id: grid

                x: 16
                y: tabs.y + tabs.height + 6
                width: parent.width - 32
                height: parent.height - y - 40
                cellWidth: 47
                cellHeight: 44
                clip: true
                model: root.results
                currentIndex: 0
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds

                highlight: Rectangle {
                    radius: 12
                    color: root.col("bgAccent", "#2679cc65")
                    border.color: root.col("accent", "#79cc65")
                    border.width: 1
                }

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.e
                        font.pixelSize: 24
                        font.family: "Noto Color Emoji"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: grid.currentIndex = parent.index
                        onClicked: root.choose(parent.modelData)
                    }

                }

            }

            Text {
                anchors.left: parent.left
                anchors.right: hint.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                anchors.bottomMargin: 12
                elide: Text.ElideRight
                color: root.col("muted", "#66f0f3f1")
                font.pixelSize: 12
                text: (root.results.length > 0 && grid.currentIndex >= 0 && grid.currentIndex < root.results.length) ? root.results[grid.currentIndex].n.replace(/_/g, " ") : "No results"
            }

            Text {
                id: hint

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 16
                anchors.bottomMargin: 12
                color: root.col("muted", "#66f0f3f1")
                font.pixelSize: 12
                text: "Tab category  ·  Esc close"
            }

        }

    }

}
