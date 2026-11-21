import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

// Saved NetworkManager connection card. All state/actions remain owned by WifiList.
ColumnLayout {
    id: savedProfileDelegate
    property var controller
    property var profileData: ({})
    property bool showEditPassword: false
    Layout.fillWidth: true
    spacing: Constants.sizeXs

    Rectangle {
        Layout.fillWidth: true
        radius: Constants.sizeMd
        color: Theme.bgSecondary
        border.width: 1
        border.color: Theme.border
        implicitHeight: savedProfileContents.implicitHeight + Constants.sizeMd * 2

        ColumnLayout {
            id: savedProfileContents
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Constants.sizeMd
            spacing: Constants.sizeSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    ThemedText {
                        text: savedProfileDelegate.profileData.ssid
                        color: Theme.fg
                        customSize: Constants.sizeSm
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    ThemedText {
                        text: savedProfileDelegate.profileData.profile_name
                        color: Theme.muted
                        customSize: Constants.sizeXs + 2
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    implicitWidth: savedEditLabel.implicitWidth + Constants.sizeSm * 2
                    implicitHeight: Constants.size2Xl + 4
                    radius: height / 2
                    color: Theme.bgAccent

                    ThemedText {
                        id: savedEditLabel
                        anchors.centerIn: parent
                        text: savedProfileDelegate.profileData.can_change_password ? "Edit pass" : "Settings"
                        color: Theme.fg
                        customSize: Constants.sizeXs + 2
                        font.bold: true
                    }

                    TapHandler {
                        onTapped: {
                            controller.savedActionMessage = "";
                            controller.savedActionSuccess = false;
                            if (savedProfileDelegate.profileData.can_change_password) {
                                controller.editingProfileUuid = savedProfileDelegate.profileData.profile_uuid;
                                controller.newSavedPassword = "";
                                savedProfileDelegate.showEditPassword = false;
                                savedPasswordFocusTimer.restart();
                            } else {
                                controller.openConnectionEditor();
                            }
                        }
                    }
                }

                Rectangle {
                    visible: savedProfileDelegate.profileData.can_change_password
                        && savedProfileDelegate.profileData.has_password
                    implicitWidth: revealPasswordLabel.implicitWidth + Constants.sizeSm * 2
                    implicitHeight: Constants.size2Xl + 4
                    radius: height / 2
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    ThemedText {
                        id: revealPasswordLabel
                        anchors.centerIn: parent
                        text: controller.loadingSavedPasswordUuid === savedProfileDelegate.profileData.profile_uuid
                            ? "Loading..."
                            : (controller.shownSavedPasswordUuid === savedProfileDelegate.profileData.profile_uuid
                                ? "Hide pass" : "Show pass")
                        color: Theme.fg
                        customSize: Constants.sizeXs + 2
                    }

                    TapHandler {
                        enabled: controller.loadingSavedPasswordUuid === ""
                            || controller.loadingSavedPasswordUuid === savedProfileDelegate.profileData.profile_uuid
                        onTapped: controller.toggleSavedPassword(savedProfileDelegate.profileData)
                    }
                }

                Rectangle {
                    implicitWidth: Constants.size2Xl + 4
                    implicitHeight: Constants.size2Xl + 4
                    radius: Constants.sizeSm
                    color: Theme.bg

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "trash"
                        iconColor: Theme.accentComplementary
                        iconSize: Constants.sizeSm + 2
                        flat: true
                    }

                    TapHandler {
                        onTapped: controller.askForgetProfile(
                            savedProfileDelegate.profileData.ssid,
                            savedProfileDelegate.profileData.profile_uuid
                        )
                    }
                }
            }

            ColumnLayout {
                visible: controller.shownSavedPasswordUuid === savedProfileDelegate.profileData.profile_uuid
                Layout.fillWidth: true
                spacing: Constants.sizeXs

                ThemedText {
                    text: "Saved password — select the text to copy it"
                    color: Theme.muted
                    customSize: Constants.sizeXs + 2
                    Layout.fillWidth: true
                }

                VeyraTextField {
                    Layout.fillWidth: true
                    text: controller.shownSavedPassword
                    readOnly: true
                    selectByMouse: true
                    echoMode: TextInput.Normal
                    color: Theme.fg

                    background: Rectangle {
                        radius: Constants.sizeSm
                        color: Theme.isDark
                            ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                            : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                        border.width: 1
                        border.color: Theme.border
                    }
                }
            }

            ColumnLayout {
                visible: controller.editingProfileUuid === savedProfileDelegate.profileData.profile_uuid
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                ThemedText {
                    text: "Enter the new Wi-Fi password"
                    color: Theme.muted
                    customSize: Constants.sizeXs + 2
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeXs

                    VeyraTextField {
                        id: savedPasswordField
                        Layout.fillWidth: true
                        echoMode: savedProfileDelegate.showEditPassword
                            ? TextInput.Normal : TextInput.Password
                        placeholderText: "New password"
                        color: Theme.fg
                        placeholderTextColor: Theme.muted
                        selectByMouse: true
                        enabled: !controller.savedPasswordBusy

                        onTextChanged: {
                            if (controller.editingProfileUuid === savedProfileDelegate.profileData.profile_uuid)
                                controller.newSavedPassword = text;
                        }

                        onAccepted: controller.saveSavedPassword(
                            savedProfileDelegate.profileData.profile_uuid
                        )

                        background: Rectangle {
                            radius: Constants.sizeSm
                            color: Theme.isDark
                                ? Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.68)
                                : Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, 0.82)
                            border.width: savedPasswordField.activeFocus ? 1.5 : 1
                            border.color: savedPasswordField.activeFocus ? Theme.accent : (savedPasswordField.hovered ? Theme.muted : Theme.border)
                        }
                    }

                    Rectangle {
                        implicitWidth: editVisibilityLabel.implicitWidth + Constants.sizeMd * 2
                        implicitHeight: savedPasswordField.implicitHeight
                        radius: height / 2
                        color: Theme.bg
                        border.width: 1
                        border.color: Theme.border

                        ThemedText {
                            id: editVisibilityLabel
                            anchors.centerIn: parent
                            text: savedProfileDelegate.showEditPassword ? "Hide" : "Show"
                            color: Theme.fg
                            customSize: Constants.sizeXs + 2
                        }

                        TapHandler {
                            onTapped: savedProfileDelegate.showEditPassword =
                                !savedProfileDelegate.showEditPassword
                        }
                    }
                }

                Connections {
                    target: controller

                    function onEditingProfileUuidChanged() {
                        savedPasswordField.text = "";

                        if (controller.editingProfileUuid === savedProfileDelegate.profileData.profile_uuid) {
                            savedProfileDelegate.showEditPassword = false;
                            savedPasswordFocusTimer.restart();
                        } else {
                            savedPasswordFocusTimer.stop();
                        }
                    }
                }

                Timer {
                    id: savedPasswordFocusTimer
                    interval: 150
                    repeat: false

                    onTriggered: {
                        if (controller.editingProfileUuid === savedProfileDelegate.profileData.profile_uuid)
                            savedPasswordField.forceActiveFocus();
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeSm
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: cancelSavedLabel.implicitWidth + Constants.sizeMd * 2
                        implicitHeight: 30
                        radius: height / 2
                        color: Theme.bg

                        ThemedText {
                            id: cancelSavedLabel
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.fg
                            customSize: Constants.sizeXs + 2
                        }

                        TapHandler {
                            onTapped: {
                                controller.editingProfileUuid = "";
                                controller.newSavedPassword = "";
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: saveSavedLabel.implicitWidth + Constants.sizeMd * 2
                        implicitHeight: 30
                        radius: height / 2
                        color: Theme.accent
                        opacity: controller.newSavedPassword !== "" && !controller.savedPasswordBusy ? 1 : 0.5

                        ThemedText {
                            id: saveSavedLabel
                            anchors.centerIn: parent
                            text: controller.savedPasswordBusy ? "Saving..." : "Save"
                            color: Theme.bg
                            customSize: Constants.sizeXs + 2
                            font.bold: true
                        }

                        TapHandler {
                            enabled: controller.newSavedPassword !== "" && !controller.savedPasswordBusy
                            onTapped: controller.saveSavedPassword(savedProfileDelegate.profileData.profile_uuid)
                        }
                    }
                }
            }
        }
    }
}
