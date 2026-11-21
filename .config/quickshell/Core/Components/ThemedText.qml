import QtQuick
import QtQuick.Window
import qs.Core
import qs.Core.Services

Text {
    property int customSize: Constants.sizeSm

    font.family: Constants.fontFamily
    // Text inside Veyra Settings gets a readability floor (min 12px, +1px).
    font.pixelSize: Math.round(((Window.window && Window.window.title === "Veyra Settings") ? Math.max(12, customSize + 1) : customSize) * SettingsService.fontScale)
    color: Theme.fg
}
