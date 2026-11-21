import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

ColumnLayout {
    id: root

    property var widget
    property bool isVertical: false
    spacing: Constants.sizeMd
    implicitWidth: Math.max(updatesCard.implicitWidth, quickNoteWidget.implicitWidth, quoteWidget.implicitWidth)
    implicitHeight: updatesCard.implicitHeight + spacing + quickNoteWidget.implicitHeight + spacing + quoteWidget.implicitHeight

    UpdatesCard {
        id: updatesCard
        widget: root.widget
        Layout.fillWidth: true
        Layout.fillHeight: false
    }

    QuickNoteWidget {
        id: quickNoteWidget
        Layout.fillWidth: true
        Layout.fillHeight: false
    }

    QuoteWidget {
        id: quoteWidget
        Layout.fillWidth: true
        Layout.fillHeight: false
    }
}
