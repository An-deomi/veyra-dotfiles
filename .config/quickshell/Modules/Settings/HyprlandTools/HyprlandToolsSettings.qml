import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    pageTitle: "Window Rules & Displays"
    pageDescription: "Control where apps open and save reliable layouts for each of your displays."
    pageIcon: "monitor-cog"

    property var pendingMonitors: []
    property int selectedMonitorIndex: 0
    property var customRules: []
    property string monitorStatus: ""
    property string rulesStatus: ""
    property bool ruleFloat: true
    property bool ruleCenter: false
    property bool rulePin: false
    property bool ruleMaximize: false
    property bool ruleNoBlur: false
    property bool ruleNoShadow: false
    property bool ruleNoAnim: false
    property bool ruleNoFocus: false
    property real ruleOpacity: 1.0
    property int ruleRounding: 0
    property string ruleMonitor: ""
    property int editingRuleIndex: -1

    readonly property var selectedMonitor: selectedMonitorIndex >= 0 && selectedMonitorIndex < pendingMonitors.length
        ? pendingMonitors[selectedMonitorIndex] : null
    readonly property var monitorNames: pendingMonitors.map((monitor) => monitor.output)
    readonly property var monitorModes: selectedMonitor
        ? ["preferred"].concat(selectedMonitor.availableModes || []) : ["preferred"]

    function refreshMonitors() {
        monitorReadProc.running = false;
        monitorReadProc.running = true;
    }

    function updateSelectedMonitor(key, value) {
        if (!selectedMonitor)
            return;
        const next = pendingMonitors.slice();
        const updated = Object.assign({}, selectedMonitor);
        updated[key] = value;
        next[selectedMonitorIndex] = updated;
        pendingMonitors = next;
    }

    function syncMonitorPositionField() {
        monitorPositionField.text = selectedMonitor ? selectedMonitor.position : "auto";
    }

    onSelectedMonitorIndexChanged: Qt.callLater(function() { root.syncMonitorPositionField(); })

    function applyAndSaveMonitors() {
        if (pendingMonitors.length === 0)
            return;
        applyCurrentDialog.open();
    }

    function commitApplyAndSaveMonitors() {
        monitorStatus = "Applying display configuration…";
        saveMonitorProc.command = ["python3", Quickshell.shellDir + "/Scripts/system/manage_hypr_desktop.py", "save-monitors"];
        saveMonitorProc.running = false;
        saveMonitorProc.running = true;
        saveMonitorProc.write(JSON.stringify(pendingMonitors) + "\n");
        saveMonitorProc.stdinEnabled = false;
    }

    function addWindowRule() {
        const className = ruleClassField.text.trim();
        const title = ruleTitleField.text.trim();
        const workspace = ruleWorkspaceField.text.trim();
        if (!className && !title) {
            rulesStatus = "Enter an application class or a window title.";
            return;
        }
        const next = customRules.slice();
        const updatedRule = {
            class: className,
            title: title,
            float: ruleFloat,
            center: ruleCenter,
            pin: rulePin,
            maximize: ruleMaximize,
            no_blur: ruleNoBlur,
            no_shadow: ruleNoShadow,
            no_anim: ruleNoAnim,
            no_focus: ruleNoFocus,
            opacity: ruleOpacity,
            rounding: ruleRounding,
            workspace: workspace,
            monitor: ruleMonitorField.text.trim()
        };
        if (editingRuleIndex >= 0 && editingRuleIndex < next.length) {
            next[editingRuleIndex] = updatedRule;
            rulesStatus = "Rule updated. Save your rules to write the Hyprland file.";
        } else {
            next.push(updatedRule);
            rulesStatus = "Rule added. Save your rules to write the Hyprland file.";
        }
        customRules = next;
        editingRuleIndex = -1;
        ruleClassField.text = "";
        ruleTitleField.text = "";
        ruleWorkspaceField.text = "";
        ruleFloat = true;
        ruleCenter = false;
        rulePin = false;
        ruleMaximize = false;
        ruleNoBlur = false;
        ruleNoShadow = false;
        ruleNoAnim = false;
        ruleNoFocus = false;
        ruleOpacity = 1.0;
        ruleRounding = 0;
        ruleMonitor = "";
        ruleMonitorField.text = "";
    }

    function editWindowRule(index) {
        if (index < 0 || index >= customRules.length)
            return;
        const rule = customRules[index];
        editingRuleIndex = index;
        ruleClassField.text = rule.class || "";
        ruleTitleField.text = rule.title || "";
        ruleWorkspaceField.text = rule.workspace || "";
        ruleFloat = !!rule.float;
        ruleCenter = !!rule.center;
        rulePin = !!rule.pin;
        ruleMaximize = !!rule.maximize;
        ruleNoBlur = !!rule.no_blur;
        ruleNoShadow = !!rule.no_shadow;
        ruleNoAnim = !!rule.no_anim;
        ruleNoFocus = !!rule.no_focus;
        ruleOpacity = Number(rule.opacity || 1.0);
        ruleRounding = Number(rule.rounding || 0);
        ruleMonitor = rule.monitor || "";
        ruleMonitorField.text = ruleMonitor;
        rulesStatus = "Editing rule. Save changes to write the Hyprland file.";
    }

    function removeWindowRule(index) {
        const next = customRules.slice();
        next.splice(index, 1);
        customRules = next;
        if (editingRuleIndex === index)
            editingRuleIndex = -1;
        else if (editingRuleIndex > index)
            editingRuleIndex -= 1;
        rulesStatus = "Rule removed. Save your rules to update the Hyprland file.";
    }

    function saveWindowRules() {
        rulesStatus = "Saving custom window rules…";
        saveRulesProc.command = ["python3", Quickshell.shellDir + "/Scripts/system/manage_hypr_desktop.py", "save-rules"];
        saveRulesProc.running = false;
        saveRulesProc.running = true;
        saveRulesProc.write(JSON.stringify(customRules) + "\n");
    }

    Component.onCompleted: {
        refreshMonitors();
        rulesReadProc.running = true;
    }

    AppGroup {
        title: "Connected Displays"
        icon: "monitor"
        badge: root.pendingMonitors.length ? root.pendingMonitors.length + " DETECTED" : "SCANNING"

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedText {
                Layout.fillWidth: true
                text: root.selectedMonitor
                    ? (root.selectedMonitor.description || root.selectedMonitor.output) + " · " + root.selectedMonitor.output
                    : "No monitor information loaded"
                color: Theme.muted
                customSize: Constants.sizeXs + 1
                elide: Text.ElideRight
            }
            ThemeButton {
                text: "Refresh"
                onClicked: root.refreshMonitors()
            }
        }

        ThemedSelect {
            label: "Display"
            description: "Choose which connected monitor to edit."
            model: root.monitorNames
            currentIndex: root.selectedMonitorIndex
            enabled: root.monitorNames.length > 0
            comboWidth: 220
            onActivated: (index) => root.selectedMonitorIndex = index
        }

        ThemedTextField {
            id: monitorPositionField
            label: "Position"
            placeholderText: "auto or 0x0"
            enabled: !!root.selectedMonitor
            Component.onCompleted: root.syncMonitorPositionField()
            onEditingFinished: root.updateSelectedMonitor("position", text.trim() || "auto")
        }

        ThemedSelect {
            label: "Resolution & Refresh Rate"
            description: "Only modes reported by this display are offered."
            model: root.monitorModes
            currentIndex: root.selectedMonitor ? Math.max(0, root.monitorModes.indexOf(root.selectedMonitor.mode)) : 0
            enabled: !!root.selectedMonitor
            comboWidth: 220
            fallbackText: "Preferred"
            onActivated: (index) => root.updateSelectedMonitor("mode", root.monitorModes[index])
        }

        SettingSpinBox {
            label: "Display Scale"
            description: "Fractional scaling for the selected monitor."
            from: 0.5
            to: 3.0
            stepSize: 0.05
            decimals: 2
            value: root.selectedMonitor ? root.selectedMonitor.scale : 1
            defaultValue: 1
            enabled: !!root.selectedMonitor
            onMoved: (value) => root.updateSelectedMonitor("scale", value)
        }

        SettingSegmented {
            label: "Display Rotation"
            description: "Rotate or flip the selected output. The saved setting is loaded by Hyprland on reload."
            model: [
                { "text": "Normal", "value": 0 },
                { "text": "90°", "value": 1 },
                { "text": "180°", "value": 2 },
                { "text": "270°", "value": 3 }
            ]
            currentValue: root.selectedMonitor ? Number(root.selectedMonitor.transform || 0) : 0
            enabled: !!root.selectedMonitor
            onActivated: (value) => root.updateSelectedMonitor("transform", value)
        }

        ThemedSelect {
            label: "Variable Refresh Rate"
            description: "Save an adaptive sync mode for this output; it takes effect on the next Hyprland reload."
            model: ["Follow global", "Off", "On", "Fullscreen", "Fullscreen video / game"]
            currentIndex: root.selectedMonitor ? Number(root.selectedMonitor.vrr || 0) + 1 : 1
            enabled: !!root.selectedMonitor
            comboWidth: 220
            onActivated: (index) => root.updateSelectedMonitor("vrr", index - 1)
        }

        InfoRow {
            label: "Current position"
            value: root.selectedMonitor ? root.selectedMonitor.position : "—"
            icon: "move"
        }

        ThemeButton {
            text: "Apply Display Settings"
            enabled: root.pendingMonitors.length > 0
            Layout.alignment: Qt.AlignRight
            onClicked: root.applyAndSaveMonitors()
        }

        ThemedText {
            text: root.monitorStatus
            visible: text !== ""
            color: Theme.accent
            customSize: Constants.sizeXs + 1
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        ThemedText {
            text: "Applying saves the connected display settings directly to ~/.config/hypr/monitors.lua and reloads Hyprland."
            color: Theme.muted
            customSize: Constants.sizeXs
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }

    AppGroup {
        title: "Custom Window Rules"
        icon: "app-window"
        badge: root.customRules.length + " RULES"

        ThemedText {
            text: "Create simple per-application rules. Match by class or title, then choose floating, centered, opacity and workspace behavior."
            color: Theme.muted
            customSize: Constants.sizeXs + 1
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        ThemedTextField {
            id: ruleClassField
            label: "Application class / app ID"
            placeholderText: "firefox, kitty, org.kde.dolphin"
        }
        ThemedTextField {
            id: ruleTitleField
            label: "Window title (optional)"
            placeholderText: "Settings, Picture-in-Picture"
        }

        SettingToggle {
            label: "Float window"
            description: "Open matching windows as floating windows."
            Binding on checked { value: root.ruleFloat }
            onToggled: (value) => root.ruleFloat = value
        }
        SettingToggle {
            label: "Center window"
            description: "Center the window. This also enables floating."
            Binding on checked { value: root.ruleCenter }
            onToggled: (value) => {
                root.ruleCenter = value;
                if (value)
                    root.ruleFloat = true;
            }
        }
        SettingSpinBox {
            label: "Opacity"
            description: "100% leaves the application fully opaque."
            from: 50
            to: 100
            stepSize: 5
            value: Math.round(root.ruleOpacity * 100)
            defaultValue: 100
            suffix: "%"
            onMoved: (value) => root.ruleOpacity = value / 100
        }
        ThemedTextField {
            id: ruleWorkspaceField
            label: "Workspace (optional)"
            placeholderText: "e.g. 3 or name:work"
        }
        ThemedTextField {
            id: ruleMonitorField
            label: "Target monitor (optional)"
            placeholderText: "e.g. DP-1 or eDP-1"
        }

        SettingToggle {
            label: "Pin to all workspaces"
            description: "Keep a floating window visible across workspaces."
            Binding on checked { value: root.rulePin }
            onToggled: (value) => { root.rulePin = value; if (value) root.ruleFloat = true; }
        }
        SettingToggle {
            label: "Maximize window"
            description: "Open the matching window maximized."
            Binding on checked { value: root.ruleMaximize }
            onToggled: (value) => root.ruleMaximize = value
        }
        SettingToggle {
            label: "Disable blur"
            description: "Keep this application's window background sharp."
            Binding on checked { value: root.ruleNoBlur }
            onToggled: (value) => root.ruleNoBlur = value
        }
        SettingToggle {
            label: "Disable shadow"
            description: "Remove the compositor shadow from this window."
            Binding on checked { value: root.ruleNoShadow }
            onToggled: (value) => root.ruleNoShadow = value
        }
        SettingToggle {
            label: "Disable animations"
            description: "Open and switch this window without window animations."
            Binding on checked { value: root.ruleNoAnim }
            onToggled: (value) => root.ruleNoAnim = value
        }
        SettingToggle {
            label: "Do not focus on open"
            description: "Open the matching window without taking keyboard focus."
            Binding on checked { value: root.ruleNoFocus }
            onToggled: (value) => root.ruleNoFocus = value
        }
        SettingSpinBox {
            label: "Window corner radius"
            description: "Override the global rounding for this application. Zero uses the global setting."
            from: 0
            to: 40
            stepSize: 1
            value: root.ruleRounding
            defaultValue: 0
            suffix: " px"
            onMoved: (value) => root.ruleRounding = value
        }

        RowLayout {
            Layout.fillWidth: true
            ThemeButton {
                text: root.editingRuleIndex >= 0 ? "Update Rule" : "Add Rule"
                onClicked: root.addWindowRule()
            }
            ThemeButton {
                text: "Cancel Edit"
                visible: root.editingRuleIndex >= 0
                onClicked: {
                    root.editingRuleIndex = -1;
                    ruleClassField.text = "";
                    ruleTitleField.text = "";
                    ruleWorkspaceField.text = "";
                    root.ruleFloat = true;
                    root.ruleCenter = false;
                    root.rulePin = false;
                    root.ruleMaximize = false;
                    root.ruleNoBlur = false;
                    root.ruleNoShadow = false;
                    root.ruleNoAnim = false;
                    root.ruleNoFocus = false;
                    root.ruleOpacity = 1.0;
                    root.ruleRounding = 0;
                    root.ruleMonitor = "";
                    ruleMonitorField.text = "";
                }
            }
            ThemeButton {
                text: "Save Rules"
                enabled: root.customRules.length >= 0
                onClicked: root.saveWindowRules()
            }
        }

        Repeater {
            model: root.customRules
            delegate: Card {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 62
                contentPadding: Constants.sizeSm
                backgroundColor: Theme.bgSecondary

                RowLayout {
                    anchors.fill: parent
                    spacing: Constants.sizeSm
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        ThemedText {
                            text: modelData.class || ("Title: " + modelData.title)
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        ThemedText {
                            text: (modelData.float ? "Floating" : "Tiled")
                                + (modelData.center ? " · Centered" : "")
                                + (modelData.pin ? " · Pinned" : "")
                                + (modelData.maximize ? " · Maximized" : "")
                                + (modelData.no_blur ? " · No blur" : "")
                                + (modelData.no_shadow ? " · No shadow" : "")
                                + (modelData.no_anim ? " · No animations" : "")
                                + (modelData.opacity < 1 ? " · " + Math.round(modelData.opacity * 100) + "% opacity" : "")
                                + (modelData.rounding ? " · " + modelData.rounding + "px rounding" : "")
                                + (modelData.workspace ? " · Workspace " + modelData.workspace : "")
                                + (modelData.monitor ? " · " + modelData.monitor : "")
                            color: Theme.muted
                            customSize: Constants.sizeXs
                            elide: Text.ElideRight
                        }
                    }
                    ThemeButton {
                        text: "Edit"
                        onClicked: root.editWindowRule(index)
                    }
                    ThemeButton {
                        text: "Remove"
                        onClicked: root.removeWindowRule(index)
                    }
                }
            }
        }

        ThemedText {
            text: root.customRules.length === 0 ? "No custom rules yet." : root.rulesStatus
            color: Theme.muted
            customSize: Constants.sizeXs + 1
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        ThemedText {
            text: "Saved rules are written to ~/.config/hypr/windowrules.local.lua. They take effect after the updated Veyra Hyprland rules module is installed and Hyprland is reloaded."
            color: Theme.muted
            customSize: Constants.sizeXs
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }

    Dialog {
        id: applyCurrentDialog
        width: 440
        title: "Apply current display setup?"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        contentItem: Item {
            implicitWidth: 400
            implicitHeight: applyCurrentMessage.implicitHeight + 20
            ThemedText {
                id: applyCurrentMessage
                anchors.fill: parent
                anchors.margins: 10
                text: "The selected resolution, position and scale will be applied to your active displays. If the result is not right, reopen this page and restore the previous setup."
                wrapMode: Text.WordWrap
                color: Theme.fg
            }
        }
        onAccepted: root.commitApplyAndSaveMonitors()
    }

    Process {
        id: monitorReadProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { id: monitorReadOutput }
        onExited: (code) => {
            if (code !== 0) {
                root.monitorStatus = "Could not read monitors. Is Hyprland running?";
                return;
            }
            try {
                const found = JSON.parse(monitorReadOutput.text || "[]");
                root.pendingMonitors = found.map((monitor) => {
                    const modes = Array.isArray(monitor.availableModes) ? monitor.availableModes : [];
                    const rate = Number(monitor.refreshRate || 60).toFixed(2);
                    const currentMode = Number(monitor.width) + "x" + Number(monitor.height) + "@" + rate + "Hz";
                    return {
                        output: String(monitor.name || ""),
                        description: [monitor.make, monitor.model].filter(Boolean).join(" "),
                        mode: modes.indexOf(currentMode) >= 0 ? currentMode : "preferred",
                        currentMode: currentMode,
                        availableModes: modes,
                        position: String(monitor.x || 0) + "x" + String(monitor.y || 0),
                        scale: Number(monitor.scale || 1),
                        transform: Number(monitor.transform || 0),
                        vrr: monitor.vrr ? 1 : 0
                    };
                });
                let focused = found.findIndex((monitor) => !!monitor.focused);
                root.selectedMonitorIndex = focused >= 0 ? focused : 0;
                root.syncMonitorPositionField();
                root.monitorStatus = root.pendingMonitors.length
                    ? "Detected " + root.pendingMonitors.length + " connected display(s)."
                    : "No connected displays found.";
            } catch (error) {
                root.monitorStatus = "Could not parse monitor information: " + error;
            }
        }
    }

    Process {
        id: saveMonitorProc
        stdinEnabled: true
        stdout: StdioCollector { id: saveMonitorOutput }
        stderr: StdioCollector { id: saveMonitorError }
        onExited: (code) => {
            try {
                const result = JSON.parse(saveMonitorOutput.text || "{}");
                root.monitorStatus = result.message || (code === 0 ? "Monitor settings saved." : "Could not save monitor settings.");
            } catch (error) {
                root.monitorStatus = "Could not read the display manager result.";
            }
            if (code !== 0) {
                const detail = saveMonitorError.text.trim();
                root.monitorStatus = "Display update failed: " + root.monitorStatus
                    + (detail ? " — " + detail : "");
            }
        }
    }

    Process {
        id: rulesReadProc
        command: ["python3", Quickshell.shellDir + "/Scripts/system/manage_hypr_desktop.py", "list-rules"]
        stdout: StdioCollector { id: rulesReadOutput }
        onExited: (code) => {
            if (code !== 0)
                return;
            try { root.customRules = JSON.parse(rulesReadOutput.text || "[]"); }
            catch (error) { root.rulesStatus = "Could not load saved rules."; }
        }
    }

    Process {
        id: saveRulesProc
        stdout: StdioCollector { id: saveRulesOutput }
        onExited: (code) => {
            try {
                const result = JSON.parse(saveRulesOutput.text || "{}");
                root.rulesStatus = result.message || (code === 0 ? "Rules saved." : "Could not save rules.");
            } catch (error) {
                root.rulesStatus = "Could not read the window-rules result.";
            }
        }
    }
}
