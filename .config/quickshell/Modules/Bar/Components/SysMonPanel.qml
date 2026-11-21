import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components

// Compact live system dashboard shown from the Island/Convex system monitor.
ColumnLayout {
    id: root

    property var stats: ({})
    property var cpuHistory: []
    property var memoryHistory: []
    property var gpuHistory: []
    property var diskHistory: []
    readonly property var gpu: stats.gpu ? stats.gpu : null
    readonly property bool gpuAwake: gpu !== null && gpu.state === "on"
    readonly property var processes: Array.isArray(stats.processes) ? stats.processes : []

    implicitWidth: 356
    spacing: Constants.sizeSm
    Component.onDestruction: sysmon.running = false

    function recordSample(history, fraction) {
        let sample = Number(fraction);
        if (!isFinite(sample)) sample = 0;
        sample = Math.max(0, Math.min(1, sample));
        let next = (history || []).slice();
        next.push(sample);
        if (next.length > 36) next = next.slice(next.length - 36);
        return next;
    }

    function gb(mb) {
        return (mb === undefined || mb === null) ? "–" : (Number(mb) / 1024).toFixed(1);
    }

    function pct(value) {
        const n = Number(value);
        return isFinite(n) ? Math.round(n) + "%" : "–";
    }

    function rate(bytes) {
        const n = Number(bytes);
        if (!isFinite(n)) return "–";
        if (n >= 1048576) return (n / 1048576).toFixed(1) + " MB/s";
        if (n >= 1024) return (n / 1024).toFixed(0) + " KB/s";
        return Math.round(n) + " B/s";
    }

    function temperature(value) {
        return value === undefined || value === null ? "" : Math.round(value) + "°C";
    }

    function formatUptime(seconds) {
        const total = Math.max(0, Number(seconds) || 0);
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        return days > 0 ? days + "d " + hours + "h" : hours + "h " + minutes + "m";
    }

    Process {
        id: sysmon
        command: ["python3", Quickshell.shellDir + "/Scripts/system/island_stats.py"]
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                try {
                    root.stats = JSON.parse(data);
                    root.cpuHistory = root.recordSample(root.cpuHistory, (root.stats.cpu || 0) / 100);
                    root.memoryHistory = root.recordSample(root.memoryHistory, (root.stats.ramUsed || 0) / Math.max(1, root.stats.ramTotal || 1));
                    root.gpuHistory = root.recordSample(root.gpuHistory, root.stats.gpu && root.stats.gpu.state === "on" ? (root.stats.gpu.util || 0) / 100 : 0);
                    root.diskHistory = root.recordSample(root.diskHistory, (root.stats.diskUsed || 0) / Math.max(1, root.stats.diskTotal || 1));
                } catch (e) {
                    console.warn("System monitor: ignored invalid stats sample", e);
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Constants.sizeSm

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            ThemedText {
                text: "Performance"
                customSize: Constants.sizeLg
                font.bold: true
            }

            ThemedText {
                text: "Live system telemetry"
                customSize: 10
                color: Theme.muted
            }
        }

        Rectangle {
            radius: height / 2
            color: Theme.bgAccent
            implicitWidth: 46
            implicitHeight: 20
            Row {
                anchors.centerIn: parent
                spacing: 4
                Rectangle {
                    width: 5; height: 5; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                }
                ThemedText { text: "LIVE"; customSize: 8; font.bold: true; color: Theme.accent }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ThemedText {
            Layout.fillWidth: true
            text: "UPTIME  " + root.formatUptime(root.stats.uptime)
            customSize: 9
            color: Theme.muted
        }
        ThemedText {
            Layout.fillWidth: true
            text: "LOAD  " + (root.stats.load && root.stats.load.length ? root.stats.load.join("  ·  ") : "–")
            customSize: 9
            color: Theme.muted
            horizontalAlignment: Text.AlignRight
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 7
        columnSpacing: 7

        SysMonMetricCard {
            Layout.fillWidth: true
            label: "PROCESSOR"
            iconName: "cpu"
            valueText: root.pct(root.stats.cpu)
            detailText: root.temperature(root.stats.cpuTemp) || "CPU utilization"
            fraction: (root.stats.cpu || 0) / 100
            history: root.cpuHistory
        }

        SysMonMetricCard {
            Layout.fillWidth: true
            label: "MEMORY"
            iconName: "layers"
            valueText: root.gb(root.stats.ramUsed) + " / " + root.gb(root.stats.ramTotal) + " GB"
            detailText: root.pct((root.stats.ramUsed || 0) / Math.max(1, root.stats.ramTotal || 1) * 100) + " used"
            fraction: (root.stats.ramUsed || 0) / Math.max(1, root.stats.ramTotal || 1)
            history: root.memoryHistory
        }

        SysMonMetricCard {
            Layout.fillWidth: true
            label: "GRAPHICS"
            iconName: "monitor"
            valueText: root.gpuAwake ? root.pct(root.gpu.util) : (root.gpu !== null ? "Sleeping" : "Unavailable")
            detailText: root.gpuAwake ? (root.temperature(root.gpu.temp) + "  ·  " + root.gb(root.gpu.memUsed) + " / " + root.gb(root.gpu.memTotal) + " GB VRAM") : "NVIDIA discrete GPU"
            fraction: root.gpuAwake ? (root.gpu.util || 0) / 100 : 0
            history: root.gpuHistory
        }

        SysMonMetricCard {
            Layout.fillWidth: true
            label: "STORAGE · HOME"
            iconName: "folder"
            valueText: root.gb(root.stats.diskUsed) + " / " + root.gb(root.stats.diskTotal) + " GB"
            detailText: root.pct((root.stats.diskUsed || 0) / Math.max(1, root.stats.diskTotal || 1) * 100) + " used"
            fraction: (root.stats.diskUsed || 0) / Math.max(1, root.stats.diskTotal || 1)
            history: root.diskHistory
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 48
        radius: Constants.sizeMd
        color: Theme.bgSecondary
        border.width: 1
        border.color: Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            SvgIcon { icon: "download"; iconSize: 14; iconColor: Theme.accent }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                ThemedText { text: "DOWNLOAD"; customSize: 8; color: Theme.muted; font.bold: true }
                ThemedText { text: root.rate(root.stats.rx); customSize: 11; font.bold: true }
            }
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.border }
            SvgIcon { icon: "chevron-up"; iconSize: 14; iconColor: Theme.accent }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                ThemedText { text: "UPLOAD"; customSize: 8; color: Theme.muted; font.bold: true }
                ThemedText { text: root.rate(root.stats.tx); customSize: 11; font.bold: true }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        ThemedText { text: "TOP PROCESSES"; customSize: 9; color: Theme.muted; font.bold: true; Layout.fillWidth: true }
        ThemedText { text: "CPU"; customSize: 8; color: Theme.muted; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 42 }
        ThemedText { text: "RAM"; customSize: 8; color: Theme.muted; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 42 }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: root.processes.slice(0, 4)
            delegate: SysMonProcessRow {
                required property var modelData
                processName: modelData.name || "Unknown"
                pidText: String(modelData.pid || "")
                cpuText: Number(modelData.cpu || 0).toFixed(1) + "%"
                memoryText: Number(modelData.mem || 0).toFixed(1) + "%"
            }
        }

        ThemedText {
            visible: root.processes.length === 0
            Layout.fillWidth: true
            text: "Process details unavailable"
            customSize: 9
            color: Theme.muted
        }
    }

    RowLayout {
        Layout.fillWidth: true
        ThemedText {
            Layout.fillWidth: true
            text: "SWAP  " + root.gb(root.stats.swapUsed) + " / " + root.gb(root.stats.swapTotal) + " GB"
            customSize: 9
            color: Theme.muted
        }
        ThemedText {
            text: "Updates every 0.5 s"
            customSize: 8
            color: Theme.muted
        }
    }
}
