import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    pageTitle: "Desktop Profiles"
    pageDescription: "Save, organize and switch between complete Veyra desktop setups."
    pageIcon: "layers"

    property string statusMessage: ""
    readonly property var savedNames: Object.keys(SettingsService.desktopProfiles || {}).sort((a, b) => a.localeCompare(b))
    readonly property var presets: [
        { name: "Gaming", description: "Reduce visual effects and keep the desktop lightweight while playing.", icon: "gamepad" },
        { name: "Focus", description: "A quieter workspace with fewer distractions and a calmer Island.", icon: "moon" },
        { name: "Minimal", description: "Compact capsules, restrained effects and more screen space.", icon: "sparkles" }
    ]

    AppGroup {
        title: "Quick Profiles"
        icon: "layers"
        badge: "PRESETS"
        columns: 2

        Repeater {
            model: root.presets

            delegate: Card {
                id: presetCard
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 132
                contentPadding: Constants.sizeMd
                cardRadius: Constants.sizeMd
                backgroundColor: Theme.bgSecondary

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Constants.sizeXs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Constants.sizeSm

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: Constants.sizeSm
                            color: Theme.bgAccent
                            SvgIcon {
                                anchors.centerIn: parent
                                icon: presetCard.modelData.icon
                                iconSize: 17
                                iconColor: Theme.accent
                                flat: true
                            }
                        }
                        ThemedText {
                            text: presetCard.modelData.name
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        ThemedText {
                            visible: SettingsService.activeDesktopProfile === presetCard.modelData.name
                            text: "ACTIVE"
                            color: Theme.accent
                            customSize: Constants.size2Xs
                            font.weight: Font.Bold
                        }
                    }

                    ThemedText {
                        text: presetCard.modelData.description
                        color: Theme.muted
                        customSize: Constants.sizeXs + 1
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    ThemeButton {
                        text: "Apply preset"
                        Layout.alignment: Qt.AlignRight
                        onClicked: {
                            if (SettingsService.applyDesktopPreset(presetCard.modelData.name))
                                root.statusMessage = presetCard.modelData.name + " profile applied.";
                            else
                                root.statusMessage = "Could not apply this preset.";
                        }
                    }
                }
            }
        }
    }

    AppGroup {
        title: "Save Current Setup"
        icon: "save"
        badge: "CUSTOM"

        ThemedText {
            text: "Capture your current Island, shell appearance, clock, notifications, wallpaper and Hyprland layout/effects."
            color: Theme.muted
            customSize: Constants.sizeXs + 1
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedTextField {
                id: profileNameField
                Layout.fillWidth: true
                label: "Profile name"
                placeholderText: "e.g. My daily setup"
            }

            ThemeButton {
                text: "Save current"
                Layout.alignment: Qt.AlignBottom
                enabled: profileNameField.text.trim().length > 0
                onClicked: {
                    const name = profileNameField.text.trim();
                    if (SettingsService.saveDesktopProfile(name)) {
                        root.statusMessage = "Saved current setup as ‘" + name + "’.";
                        profileNameField.text = "";
                    } else {
                        root.statusMessage = "Name must be unique (ignoring case), 1–32 characters; use letters, numbers, spaces, _ or -.";
                    }
                }
            }
        }
    }

    AppGroup {
        title: "Your Profiles"
        icon: "folder"
        badge: root.savedNames.length + " SAVED"

        ThemedText {
            visible: root.savedNames.length === 0
            text: "No custom profiles yet. Save your current setup above to create your first one."
            color: Theme.muted
            customSize: Constants.sizeXs + 1
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Repeater {
            model: root.savedNames

            delegate: Card {
                id: profileCard
                required property string modelData
                property bool editingName: false
                property bool confirmingDelete: false

                Layout.fillWidth: true
                contentPadding: Constants.sizeMd
                cardRadius: Constants.sizeMd
                backgroundColor: Theme.bgSecondary

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Constants.sizeSm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Constants.sizeSm

                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            radius: Constants.sizeSm
                            color: Theme.bgAccent
                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "layers"
                                iconSize: 18
                                iconColor: Theme.accent
                                flat: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            ThemedText {
                                text: profileCard.modelData
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            ThemedText {
                                text: SettingsService.activeDesktopProfile === profileCard.modelData ? "Currently active" : "Saved desktop setup"
                                color: SettingsService.activeDesktopProfile === profileCard.modelData ? Theme.accent : Theme.muted
                                customSize: Constants.sizeXs
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Constants.sizeXs

                        ThemeButton {
                            text: "Apply"
                            onClicked: {
                                if (SettingsService.applyDesktopProfile(profileCard.modelData))
                                    root.statusMessage = "Applied ‘" + profileCard.modelData + "’.";
                                else
                                    root.statusMessage = "Could not apply this profile.";
                            }
                        }
                        ThemeButton {
                            text: "Duplicate"
                            onClicked: {
                                if (SettingsService.duplicateDesktopProfile(profileCard.modelData))
                                    root.statusMessage = "Duplicated ‘" + profileCard.modelData + "’.";
                                else
                                    root.statusMessage = "Could not duplicate this profile.";
                            }
                        }
                        ThemeButton {
                            text: "Rename"
                            enabled: !profileCard.confirmingDelete
                            onClicked: {
                                profileCard.editingName = !profileCard.editingName;
                                profileCard.confirmingDelete = false;
                            }
                        }
                        ThemeButton {
                            text: "Delete"
                            enabled: !profileCard.editingName
                            onClicked: profileCard.confirmingDelete = !profileCard.confirmingDelete
                        }
                    }

                    RowLayout {
                        visible: profileCard.editingName
                        Layout.fillWidth: true
                        spacing: Constants.sizeXs

                        ThemedTextField {
                            id: renameField
                            Layout.fillWidth: true
                            label: "New profile name"
                            text: profileCard.modelData
                            placeholderText: "Enter a new name"
                        }
                        ThemeButton {
                            text: "Save name"
                            Layout.alignment: Qt.AlignBottom
                            onClicked: {
                                if (SettingsService.renameDesktopProfile(profileCard.modelData, renameField.text)) {
                                    root.statusMessage = "Profile renamed to ‘" + renameField.text.trim() + "’.";
                                    profileCard.editingName = false;
                                } else {
                                    root.statusMessage = "That name is invalid or already in use.";
                                }
                            }
                        }
                        ThemeButton {
                            text: "Cancel"
                            Layout.alignment: Qt.AlignBottom
                            onClicked: profileCard.editingName = false
                        }
                    }

                    RowLayout {
                        visible: profileCard.confirmingDelete
                        Layout.fillWidth: true
                        ThemedText {
                            text: "Delete this profile? This cannot be undone."
                            color: Theme.muted
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        ThemeButton {
                            text: "Confirm delete"
                            onClicked: {
                                if (SettingsService.deleteDesktopProfile(profileCard.modelData))
                                    root.statusMessage = "Deleted ‘" + profileCard.modelData + "’.";
                                else
                                    root.statusMessage = "Could not delete this profile.";
                            }
                        }
                        ThemeButton {
                            text: "Keep"
                            onClicked: profileCard.confirmingDelete = false
                        }
                    }
                }
            }
        }
    }

    ThemedText {
        visible: root.statusMessage !== ""
        text: root.statusMessage
        color: Theme.accent
        customSize: Constants.sizeXs + 1
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
}
