import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils

Item {
    id: root

    readonly property color onAccentColor: ColorUtils.isDark(Theme.accent) ? "#ffffff" : "#0b0b0f"

    property var widget: null
    property date now: new Date()
    property int pomoModeMinutes: 25
    property int pomoRemainingSec: 25 * 60
    property bool pomoRunning: false
    readonly property string pomoFormatted: {
        const m = Math.floor(pomoRemainingSec / 60);
        const s = pomoRemainingSec % 60;
        return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
    }

    function selectPomoMode(mins) {
        pomoRunning = false;
        pomoModeMinutes = mins;
        pomoRemainingSec = mins * 60;
    }
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    // 0 = Sunday, 1 = Monday, 6 = Saturday
    property int weekStart: 0
    readonly property int todayY: now.getFullYear()
    readonly property int todayM: now.getMonth()
    readonly property int todayD: now.getDate()
    readonly property var cells: buildCells(viewYear, viewMonth, weekStart)
    readonly property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    readonly property real cellW: Math.floor((width - Constants.size2Xs * 2 - 12) / 7)
    property var tasks: []
    property bool adding: false

    // VEYRA_PLANNER_V1
    property date selectedDate: new Date()
    property string taskViewMode: "all"
    property bool showCompletedTasks: false
    property int editingIndex: -1
    property string editText: ""
    property string editDueDate: ""
    property string editPriority: "normal"
    property string taskEditError: ""
    property var lastDeletedTask: null
    property int lastDeletedIndex: -1

    readonly property string selectedDateKey: root.dateKey(root.selectedDate)

    readonly property var matchingTaskItems: {
        const result = [];
        for (let i = 0; i < root.tasks.length; i++) {
            const task = root.tasks[i];
            if (root.taskViewMode === "all" ||
                String(task.dueDate || "") === root.selectedDateKey) {
                result.push({ index: i, task: task });
            }
        }
        return result;
    }

    readonly property var visibleTaskItems: {
        const result = [];
        for (let i = 0; i < root.matchingTaskItems.length; i++) {
            const item = root.matchingTaskItems[i];
            if (!item.task.done || root.showCompletedTasks)
                result.push(item);
        }

        result.sort(function(a, b) {
            if (a.task.done !== b.task.done)
                return a.task.done ? 1 : -1;

            function rank(priority) {
                if (priority === "high") return 0;
                if (priority === "low") return 2;
                return 1;
            }

            const priorityDifference =
                rank(a.task.priority) - rank(b.task.priority);
            if (priorityDifference !== 0)
                return priorityDifference;

            return a.index - b.index;
        });
        return result;
    }

    readonly property int completedTaskCount: {
        let count = 0;
        for (let i = 0; i < root.matchingTaskItems.length; i++) {
            if (root.matchingTaskItems[i].task.done)
                count++;
        }
        return count;
    }
    property bool savePending: false
    readonly property string todoScript: Quickshell.shellDir + "/Scripts/system/todo.py"
    readonly property string weatherScript: Quickshell.shellDir + "/Scripts/system/fetch_weather.py"
    property var weatherData: null
    property string weatherError: ""
    property string weatherRequestLocation: ""
    property bool weatherRefreshPending: false
    readonly property int doneCount: {
        let n = 0;
        for (let i = 0; i < tasks.length; i++) {
            if (tasks[i].done)
                n++;

        }
        return n;
    }

    function buildCells(y, m, ws) {
        let first = new Date(y, m, 1).getDay();
        let offset = (first - ws + 7) % 7;
        let out = [];
        for (let i = 0; i < 42; i++) {
            let d = new Date(y, m, 1 - offset + i);
            out.push({
                "day": d.getDate(),
                "m": d.getMonth(),
                "y": d.getFullYear(),
                "inMonth": d.getMonth() === m
            });
        }
        return out;
    }

    function shiftMonth(delta) {
        let d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }

    function goToday() {
        let d = new Date();
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
        selectedDate = d;
        taskViewMode = "day";
        showCompletedTasks = false;
    }

    function setAdding(on) {
        adding = on;
        AppState.textInputActive = on;
        if (on)
            focusTimer.restart();
        else
            taskField.text = "";
    }

    // VEYRA_PLANNER_V1
    function dateKey(d) {
        return d.getFullYear() + "-" +
            String(d.getMonth() + 1).padStart(2, "0") + "-" +
            String(d.getDate()).padStart(2, "0");
    }

    function selectCalendarDate(cell) {
        const d = new Date(cell.y, cell.m, cell.day);
        if (!cell.inMonth) {
            root.viewYear = d.getFullYear();
            root.viewMonth = d.getMonth();
        }
        root.selectedDate = d;
        root.taskViewMode = "day";
        root.showCompletedTasks = false;
        root.editingIndex = -1;
    }

    function taskCountForDate(y, m, d) {
        const key = root.dateKey(new Date(y, m, d));
        let count = 0;
        for (let i = 0; i < root.tasks.length; i++) {
            if (String(root.tasks[i].dueDate || "") === key)
                count++;
        }
        return count;
    }

    function formatDueDate(value) {
        if (!value || value.length !== 10)
            return "";
        return value.substring(8, 10) + "/" + value.substring(5, 7);
    }

    function isValidDueDate(value) {
        if (!value)
            return true;
        if (!/^\d{4}-\d{2}-\d{2}$/.test(value))
            return false;

        const parts = value.split("-");
        const d = new Date(
            Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])
        );
        return d.getFullYear() === Number(parts[0]) &&
            d.getMonth() === Number(parts[1]) - 1 &&
            d.getDate() === Number(parts[2]);
    }

    function nextPriority(value) {
        if (value === "normal") return "high";
        if (value === "high") return "low";
        return "normal";
    }

    function beginEdit(i) {
        const task = root.tasks[i];
        if (!task)
            return;
        root.editingIndex = i;
        root.editText = task.text;
        root.editDueDate = task.dueDate || "";
        root.editPriority = task.priority || "normal";
        root.taskEditError = "";
    }

    function commitEdit(i) {
        const text = root.editText.trim();
        const due = root.editDueDate.trim();

        if (!text) {
            root.taskEditError = "Task name cannot be empty";
            return;
        }
        if (!root.isValidDueDate(due)) {
            root.taskEditError = "Use YYYY-MM-DD or leave the date blank";
            return;
        }
        if (i < 0 || i >= root.tasks.length)
            return;

        const old = root.tasks[i];
        const next = root.tasks.slice();
        next[i] = {
            "text": text,
            "done": Boolean(old.done),
            "dueDate": due,
            "priority": root.editPriority
        };
        root.tasks = next;
        root.editingIndex = -1;
        root.taskEditError = "";
        root.save();
    }

    function cycleTaskPriority(i) {
        if (i < 0 || i >= root.tasks.length)
            return;
        const old = root.tasks[i];
        const next = root.tasks.slice();
        next[i] = {
            "text": old.text,
            "done": Boolean(old.done),
            "dueDate": old.dueDate || "",
            "priority": root.nextPriority(old.priority || "normal")
        };
        root.tasks = next;
        root.save();
    }

    function addTask(t) {
        const text = (t || "").trim();
        if (text === "")
            return;

        const due = root.taskViewMode === "day"
            ? root.selectedDateKey : "";

        root.tasks = root.tasks.concat([{
            "text": text,
            "done": false,
            "dueDate": due,
            "priority": "normal"
        }]);
        root.save();
    }

    function toggleTask(i) {
        if (i < 0 || i >= root.tasks.length)
            return;
        const old = root.tasks[i];
        const next = root.tasks.slice();
        next[i] = {
            "text": old.text,
            "done": !old.done,
            "dueDate": old.dueDate || "",
            "priority": old.priority || "normal"
        };
        root.tasks = next;
        root.save();
    }

    function removeTask(i) {
        if (i < 0 || i >= root.tasks.length)
            return;
        const old = root.tasks[i];
        root.lastDeletedTask = {
            "text": old.text,
            "done": Boolean(old.done),
            "dueDate": old.dueDate || "",
            "priority": old.priority || "normal"
        };
        root.lastDeletedIndex = i;
        const next = root.tasks.slice();
        next.splice(i, 1);
        root.tasks = next;
        if (root.editingIndex === i)
            root.editingIndex = -1;
        root.save();
    }

    function undoDelete() {
        if (root.lastDeletedTask === null)
            return;
        const next = root.tasks.slice();
        const index = Math.max(
            0, Math.min(root.lastDeletedIndex, next.length)
        );
        next.splice(index, 0, root.lastDeletedTask);
        root.tasks = next;
        root.lastDeletedTask = null;
        root.lastDeletedIndex = -1;
        root.save();
    }

    function refreshWeather(force) {
        if (!SettingsService.clockWeatherEnabled)
            return;

        const location = String(SettingsService.clockWeatherLocation || "").trim();
        if (!location) {
            weatherError = "Enter a location in Shell Settings";
            return;
        }

        if (weatherProc.running) {
            weatherRefreshPending = true;
            return;
        }

        weatherRequestLocation = location;
        weatherError = "";
        weatherProc.command = ["python3", root.weatherScript]
            .concat(force ? ["--force"] : [])
            .concat([location]);
        weatherProc.running = true;
    }

    function save() {
        if (saveProc.running) {
            savePending = true;
            return ;
        }
        saveProc.stdinEnabled = true;
        saveProc.command = ["python3", todoScript, "save"];
        saveProc.running = true;
        saveProc.write(JSON.stringify(tasks) + "\n");
        saveProc.stdinEnabled = false;
    }

    Component.onCompleted: loadProc.running = true
    Component.onDestruction: {
        if (adding)
            AppState.textInputActive = false;

    }

    Timer {
        id: focusTimer

        interval: 150
        repeat: false
        onTriggered: taskField.forceActiveFocus()
    }

    Process {
        id: loadProc

        command: ["python3", root.todoScript, "load"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let l = JSON.parse(data.trim());
                    if (Array.isArray(l))
                        root.tasks = l;

                } catch (e) {
                }
            }
        }

    }

    Process {
        id: saveProc

        onRunningChanged: {
            if (!running && root.savePending) {
                root.savePending = false;
                root.save();
            }
        }
    }

    Process {
        id: weatherProc

        stdout: StdioCollector {
            id: weatherOutput
        }

        stderr: StdioCollector {
            id: weatherErrorOutput
        }

        onExited: function(exitCode) {
            const requestStillCurrent =
                root.weatherRequestLocation ===
                String(SettingsService.clockWeatherLocation || "").trim();

            if (exitCode === 0) {
                try {
                    const result = JSON.parse(weatherOutput.text.trim());
                    if (SettingsService.clockWeatherEnabled && requestStillCurrent) {
                        root.weatherData = result;
                        root.weatherError = "";
                    }
                } catch (e) {
                    console.warn("Calendar weather: invalid response: " + e);
                    if (SettingsService.clockWeatherEnabled && requestStillCurrent)
                        root.weatherError = "Weather unavailable";
                }
            } else {
                console.warn("Calendar weather request failed: " +
                    weatherErrorOutput.text);
                if (SettingsService.clockWeatherEnabled && requestStillCurrent)
                    root.weatherError = "Weather unavailable";
            }

            if (root.weatherRefreshPending) {
                root.weatherRefreshPending = false;
                Qt.callLater(function() {
                    root.refreshWeather();
                });
            }
        }
    }

    Connections {
        target: SettingsService

        function onClockWeatherLocationChanged() {
            root.weatherData = null;
            root.weatherError = "";
            if (SettingsService.clockWeatherEnabled)
                root.refreshWeather();
        }

        function onClockWeatherEnabledChanged() {
            if (!SettingsService.clockWeatherEnabled) {
                root.weatherRefreshPending = false;
                root.weatherData = null;
                root.weatherError = "";
            }
        }
    }

    Timer {
        id: weatherRefreshTimer
        interval: 2 * 60 * 60 * 1000
        running: SettingsService.clockWeatherEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }

    implicitWidth: 300
    implicitHeight: mainCol.implicitHeight + Constants.size2Xs * 2
    width: implicitWidth
    height: implicitHeight

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date();
            if (root.pomoRunning) {
                if (root.pomoRemainingSec > 1) {
                    root.pomoRemainingSec -= 1;
                } else {
                    root.pomoRemainingSec = 0;
                    root.pomoRunning = false;
                    SettingsService.playUiSound("timer-done");
                    IslandEventService.showEvent("pomodoro", "Focus Timer", root.pomoModeMinutes + "m complete!", "clock", 100, 3200);
                }
            }
        }
    }

    ColumnLayout {
        id: mainCol

        anchors.fill: parent
        anchors.margins: Constants.size2Xs
        spacing: Constants.sizeXs

        // Header: Big Time & Format Controls
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedText {
                text: {
                    if (SettingsService.clock24h)
                        return Qt.formatDateTime(root.now, "HH:mm");

                    let h = root.now.getHours() % 12 || 12;
                    let m = root.now.getMinutes().toString().padStart(2, "0");
                    return h + ":" + m;
                }
                font.bold: true
                customSize: Constants.size4Xl - 4
                color: Theme.fg
            }

            ColumnLayout {
                spacing: Constants.size3Xs
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    visible: !SettingsService.clock24h
                    color: Theme.bgSecondary
                    radius: Constants.sizeXs - 2
                    Layout.preferredWidth: apText.implicitWidth + 10
                    Layout.preferredHeight: Constants.sizeLg + 2

                    ThemedText {
                        id: apText

                        anchors.centerIn: parent
                        text: root.now.getHours() >= 12 ? "PM" : "AM"
                        font.bold: true
                        customSize: Constants.sizeXs - 2
                        color: Theme.accent
                    }

                }

                ThemedText {
                    text: Qt.formatDateTime(root.now, ":ss")
                    customSize: Constants.sizeMd
                    font.bold: true
                    color: Theme.muted
                }

            }

            Item {
                Layout.fillWidth: true
            }

            // Dynamic Day / Night Large Icon
            SvgIcon {
                readonly property int currentHour: root.now.getHours()
                readonly property bool isDay: currentHour >= 6 && currentHour < 18

                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: Constants.size2Xs
                icon: isDay ? "sun" : "moon-filled"
                iconSize: 38
                iconColor: Theme.accent
                flat: true
            }

        }

        // Subtitle: Date & Day
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            SvgIcon {
                icon: "calendar"
                iconSize: 15
                iconColor: Theme.accent
                flat: true
            }

            ThemedText {
                text: Qt.formatDateTime(root.now, "dddd, MMMM d")
                customSize: Constants.sizeSm
                color: Theme.muted
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

        }

        Rectangle {
            visible: SettingsService.clockWeatherEnabled
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            radius: Constants.sizeMd
            color: Theme.bgSecondary

            RowLayout {
                anchors.fill: parent
                anchors.margins: Constants.sizeSm
                spacing: Constants.sizeSm

                ThemedText {
                    text: root.weatherData ? root.weatherData.emoji :
                          (root.weatherError !== "" ? "⚠️" : "…")
                    customSize: Constants.size2Xl
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Constants.size3Xs

                    ThemedText {
                        text: root.weatherData ? root.weatherData.description :
                              (root.weatherError !== "" ? "Weather unavailable" : "Loading weather…")
                        font.bold: true
                        customSize: Constants.sizeSm
                        color: Theme.fg
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    ThemedText {
                        text: root.weatherData ? root.weatherData.location :
                              SettingsService.clockWeatherLocation
                        customSize: Constants.sizeXs
                        color: Theme.muted
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    spacing: Constants.size3Xs
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                    ThemedText {
                        text: root.weatherData ?
                              Math.round(root.weatherData.temperature) + "°C" : "--"
                        font.bold: true
                        customSize: Constants.sizeXl
                        color: Theme.fg
                        Layout.alignment: Qt.AlignRight
                    }

                    ThemedText {
                        text: root.weatherData ?
                              "H " + Math.round(root.weatherData.high) + "°  L " +
                              Math.round(root.weatherData.low) + "°" : ""
                        customSize: Constants.sizeXs
                        color: Theme.muted
                        Layout.alignment: Qt.AlignRight
                    }
                }

                SvgIconButton {
                    icon: "refresh-cw"
                    iconSize: Constants.sizeMd
                    flat: true
                    onClicked: root.refreshWeather(true)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 74
            radius: Constants.sizeMd
            color: Theme.bgSecondary
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Constants.sizeSm
                spacing: Constants.sizeXs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Constants.size2Xs

                    Repeater {
                        model: [
                            { "label": "25m Focus", "mins": 25 },
                            { "label": "5m Break", "mins": 5 },
                            { "label": "15m Long", "mins": 15 }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: root.pomoModeMinutes === modelData.mins

                            Layout.preferredHeight: 20
                            Layout.preferredWidth: modeLabel.implicitWidth + 12
                            radius: height / 2
                            color: selected ? Chrome.accentTintStrong : Theme.bgTertiary
                            border.width: 1
                            border.color: selected ? Theme.accent : Theme.border

                            ThemedText {
                                id: modeLabel
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                customSize: 10
                                font.weight: parent.selected ? Font.DemiBold : Font.Normal
                                color: parent.selected ? Theme.accent : Theme.muted
                            }

                            TapHandler {
                                onTapped: root.selectPomoMode(modelData.mins)
                            }

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeXs

                    ThemedText {
                        text: root.pomoFormatted
                        customSize: Constants.sizeXl
                        font.bold: true
                        font.features: ({ "tnum": 1 })
                        color: root.pomoRunning ? Theme.accent : Theme.fg
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: startLabel.implicitWidth + 18
                        radius: height / 2
                        color: root.pomoRunning ? Theme.bgAccent : Theme.accent

                        ThemedText {
                            id: startLabel
                            anchors.centerIn: parent
                            text: root.pomoRunning ? "Pause" : (root.pomoRemainingSec === 0 ? "Restart" : "Start")
                            customSize: 11
                            font.bold: true
                            color: root.pomoRunning ? Theme.accent : root.onAccentColor
                        }

                        TapHandler {
                            onTapped: {
                                if (root.pomoRemainingSec === 0)
                                    root.pomoRemainingSec = root.pomoModeMinutes * 60;
                                root.pomoRunning = !root.pomoRunning;
                            }
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    SvgIconButton {
                        icon: "refresh-cw"
                        iconSize: Constants.sizeSm
                        flat: true
                        onClicked: root.selectPomoMode(root.pomoModeMinutes)
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                color: Theme.border

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(1, 1 - (root.pomoRemainingSec / Math.max(1, root.pomoModeMinutes * 60))))
                    color: Theme.accent
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Constants.sizeXs
            Layout.preferredHeight: 1
            color: Theme.bgSecondary
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            ThemedText {
                text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                font.bold: true
                customSize: Constants.sizeMd
                color: Theme.fg
                Layout.fillWidth: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToday()
                }

            }

            SvgIconButton {
                icon: "chevron-left"
                iconSize: Constants.sizeMd
                flat: true
                onClicked: root.shiftMonth(-1)
            }

            SvgIconButton {
                icon: "chevron-left"
                rotation: 180
                iconSize: Constants.sizeMd
                flat: true
                onClicked: root.shiftMonth(1)
            }

        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 2
            rowSpacing: 2

            Repeater {
                model: 7

                Item {
                    Layout.preferredWidth: root.cellW
                    Layout.preferredHeight: 16

                    ThemedText {
                        anchors.centerIn: parent
                        text: root.dayNames[(root.weekStart + index) % 7]
                        customSize: 10
                        font.bold: true
                        color: Theme.muted
                    }

                }

            }

        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 2
            rowSpacing: 2

            Repeater {
                model: root.cells

                Rectangle {
                    readonly property bool isToday:
                        modelData.day === root.todayD &&
                        modelData.m === root.todayM &&
                        modelData.y === root.todayY
                    readonly property bool isSelected:
                        modelData.day === root.selectedDate.getDate() &&
                        modelData.m === root.selectedDate.getMonth() &&
                        modelData.y === root.selectedDate.getFullYear()
                    readonly property bool hasTasks:
                        root.taskCountForDate(
                            modelData.y, modelData.m, modelData.day
                        ) > 0

                    Layout.preferredWidth: root.cellW
                    Layout.preferredHeight: 30
                    radius: height / 2
                    color: isSelected ? Theme.accent : "transparent"
                    border.width: isToday && !isSelected ? 1 : 0
                    border.color: Theme.accent

                    ThemedText {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: parent.hasTasks ? -2 : 0
                        text: String(modelData.day)
                        customSize: Constants.sizeSm
                        font.bold: parent.isToday || parent.isSelected
                        color: parent.isSelected ? root.onAccentColor : Theme.fg
                        opacity: modelData.inMonth ? 1 : 0.3
                    }

                    Rectangle {
                        visible: parent.hasTasks
                        width: 3
                        height: 3
                        radius: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        color: parent.isSelected ? root.onAccentColor : Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectCalendarDate(modelData)
                    }
                }

            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Constants.sizeXs
            Layout.preferredHeight: 1
            color: Theme.bgSecondary
        }

        TaskPlanner {
            Layout.fillWidth: true
            controller: root
        }
    }

}
