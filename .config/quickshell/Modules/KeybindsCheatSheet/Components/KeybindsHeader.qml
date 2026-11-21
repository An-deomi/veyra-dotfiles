import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Modules.Settings.Components

AppHeader {
    id: headerRoot

    required property var keybindsRoot
    readonly property alias searchField: searchField

    title: keybindsRoot.selectedCategory === "All" ? "All Shortcuts" : keybindsRoot.selectedCategory
    category: "SHORTCUT MANAGEMENT"
    subtitle: keybindsRoot.searchText !== "" ? (keybindsRoot.displayedBinds.length + " shortcuts found") : (keybindsRoot.selectedCategory === "All" ? (keybindsRoot.totalKeybinds + " shortcuts configured") : (keybindsRoot.categoryBindCount(keybindsRoot.selectedCategory) + " shortcuts in this category"))
    showDivider: true

    ThemeButton {
        text: "Add Shortcut"
        Layout.alignment: Qt.AlignVCenter
        onClicked: keybindsRoot.openNewShortcut()
    }

    Rectangle {
        Layout.preferredWidth: 240
        Layout.preferredHeight: 34
        color: "transparent"
        Layout.alignment: Qt.AlignVCenter

        ThemedSearchBar {
            id: searchField

            anchors.fill: parent
            customSize: Constants.sizeSm
            placeholderText: "Search shortcuts (/)..."
            text: keybindsRoot.searchText
            onSearchRequested: (text) => {
                keybindsRoot.searchText = text;
            }
            textField.Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    if (keybindsRoot.searchText !== "") {
                        keybindsRoot.searchText = "";
                        event.accepted = true;
                    }
                }
            }
        }

    }

}
