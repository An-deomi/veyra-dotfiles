import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Modules.Settings.Components

Dialog {
    id: root

    property string editingId: ""
    property string errorMessage: ""

    signal saveRequested(var shortcutData)

    modal: true
    anchors.centerIn: Overlay.overlay
    width: 520
    title: editingId === "" ? "Create custom shortcut" : "Edit custom shortcut"
    standardButtons: Dialog.NoButton

    function openNew() {
        editingId = "";
        errorMessage = "";
        nameField.text = "";
        comboField.text = "SUPER + SHIFT + K";
        commandField.text = "";
        categoryBox.currentIndex = 5;
        open();
        nameField.textField.forceActiveFocus();
    }

    function openForEdit(data) {
        editingId = data.id || "";
        errorMessage = "";
        nameField.text = data.desc || "";
        comboField.text = data.rawCombo || "";
        commandField.text = data.command || "";
        let index = categoryBox.find(data.category || "My Shortcuts");
        categoryBox.currentIndex = index >= 0 ? index : 5;
        open();
        nameField.textField.forceActiveFocus();
    }

    contentItem: ColumnLayout {
        spacing: Constants.sizeMd

        ThemedText {
            Layout.fillWidth: true
            text: "Create a shortcut that runs a command. Veyra's built-in shortcuts remain managed by the system configuration."
            color: Theme.muted
            customSize: Constants.sizeXs + 1
            wrapMode: Text.WordWrap
        }

        ThemedTextField {
            id: nameField
            label: "Shortcut name"
            placeholderText: "Open browser"
            customSize: Constants.sizeSm
        }

        ThemedTextField {
            id: comboField
            label: "Key combination"
            placeholderText: "SUPER + SHIFT + B"
            customSize: Constants.sizeSm
        }

        ThemedText {
            Layout.fillWidth: true
            text: "Use Super, Shift, Ctrl or Alt with a key, for example SUPER + ALT + B."
            color: Theme.muted
            customSize: Constants.sizeXs
            wrapMode: Text.WordWrap
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            ThemedText {
                text: "Category"
                color: Theme.fg
                customSize: Constants.sizeSm
                font.weight: Font.DemiBold
            }

            ComboBox {
                id: categoryBox
                Layout.fillWidth: true
                model: ["Applications", "Windows", "Workspaces", "System", "Quickshell", "My Shortcuts"]
                currentIndex: 5
            }
        }

        ThemedTextField {
            id: commandField
            label: "Command"
            placeholderText: "firefox --new-window"
            customSize: Constants.sizeSm
        }

        ThemedText {
            Layout.fillWidth: true
            text: "Custom shortcuts are saved in your Veyra user state and loaded by the updated Hyprland config after it is installed and reloaded."
            color: Theme.muted
            customSize: Constants.sizeXs
            wrapMode: Text.WordWrap
        }

        ThemedText {
            Layout.fillWidth: true
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: Theme.accentComplementary
            customSize: Constants.sizeXs + 1
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Constants.sizeXs
            spacing: Constants.sizeSm

            Item { Layout.fillWidth: true }

            ThemeButton {
                text: "Cancel"
                onClicked: root.reject()
            }

            ThemeButton {
                text: root.editingId === "" ? "Add Shortcut" : "Save Changes"
                enabled: nameField.text.trim() !== "" && comboField.text.trim() !== "" && commandField.text.trim() !== ""
                onClicked: {
                    root.errorMessage = "";
                    root.saveRequested({
                        "id": root.editingId,
                        "name": nameField.text.trim(),
                        "combo": comboField.text.trim(),
                        "category": categoryBox.currentText,
                        "command": commandField.text.trim()
                    });
                }
            }
        }
    }
}
