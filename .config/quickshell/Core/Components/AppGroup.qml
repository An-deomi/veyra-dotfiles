import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Card {
    id: root

    property string title: ""
    property string icon: ""
    property string badge: ""
    property bool showDividers: true
    // Gap around each divider. Kept as one value so the dividers cannot drift
    // away from the rows they separate.
    property int rowGap: Constants.sizeXl
    property int columns: 1
    // Titled groups fold like folders by default; pages that want a fixed
    // section can still set collapsible: false.
    property bool collapsible: root.title !== ""
    property bool expanded: true
    // Opt-in per group: only worth showing where the children declare defaults.
    property bool showReset: false
    // Flat groups render as plain sub-sections (no card/border) inside a parent group.
    property bool flat: false
    // Count badges ("10 controls") are hidden by default to reduce clutter.
    property bool showBadge: false
    default property alias groupContent: contentLayout.data

    // Children reset through their own signals, which keeps the value bindings
    // on the page intact (assigning to a bound property would break them).
    function resetAll() {
        for (let i = 0; i < contentLayout.children.length; i++) {
            let child = contentLayout.children[i];
            if (child && typeof child.resetToDefault === "function")
                child.resetToDefault();

        }
    }

    Layout.fillWidth: true
    contentPadding: root.flat ? 0 : Constants.sizeLg
    cardRadius: Constants.sizeMd
    useBorder: !root.flat
    backgroundColor: root.flat ? "transparent" : Theme.bgTertiary

    ColumnLayout {
        id: mainLayout

        width: parent.width
        spacing: Constants.sizeLg

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm
            visible: root.title !== ""

            Rectangle {
                visible: root.icon !== "" && root.icon !== "ghost"
                Layout.preferredWidth: Constants.size2Xl
                Layout.preferredHeight: Constants.size2Xl
                radius: Constants.sizeXs
                color: Theme.bgAccent

                SvgIcon {
                    anchors.centerIn: parent
                    icon: root.icon
                    iconSize: Constants.sizeSm
                    iconColor: Theme.accent
                    flat: true
                }
            }

            ThemedText {
                text: root.title
                customSize: Constants.sizeSm + 1
                font.weight: Font.DemiBold
                font.letterSpacing: 0.1
                color: Theme.fg
                Layout.fillWidth: true
            }

            SvgIconButton {
                visible: root.showReset
                icon: "refresh-cw"
                iconSize: Constants.sizeSm
                flat: true
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.resetAll()
            }

            Rectangle {
                visible: root.showBadge && root.badge !== ""
                radius: height / 2
                implicitWidth: badgeLabel.implicitWidth + Constants.sizeMd
                implicitHeight: Constants.sizeXl
                color: Theme.bgTertiary
                border.width: 1
                border.color: Theme.border

                ThemedText {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: root.badge
                    customSize: Constants.sizeXs + 1
                    color: Theme.muted
                    font.weight: Font.DemiBold
                }
            }

            ThemedText {
                visible: root.collapsible
                text: root.expanded ? "▾" : "›"
                customSize: 14
                color: Theme.muted
            }

            TapHandler {
                enabled: root.collapsible
                onTapped: root.expanded = !root.expanded
            }

            HoverHandler {
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

        }

        Item {
            Layout.fillWidth: true
            visible: !root.collapsible || root.expanded
            implicitHeight: contentLayout.implicitHeight

            GridLayout {
                id: contentLayout

                anchors.fill: parent
                columns: Math.max(1, root.columns)
                columnSpacing: Constants.sizeMd
                rowSpacing: root.columns > 1 ? Constants.sizeMd : root.rowGap
            }

            Repeater {
                model: contentLayout.children.length

                Divider {
                    property var targetChild: contentLayout.children[index]

                    width: parent.width
                    y: targetChild ? targetChild.y + targetChild.height + ((root.rowGap - 1) / 2) : 0
                    visible: {
                        if (!root.showDividers || root.columns > 1)
                            return false;

                        if (!targetChild || !targetChild.visible || ('delegate' in targetChild && 'model' in targetChild))
                            return false;

                        for (let i = index + 1; i < contentLayout.children.length; i++) {
                            let c = contentLayout.children[i];
                            if (c.visible && !('delegate' in c && 'model' in c))
                                return true;

                        }
                        return false;
                    }
                }

            }

        }

    }

}
