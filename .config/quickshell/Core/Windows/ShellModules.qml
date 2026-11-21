import QtQuick
import qs.Core.Components
import qs.Modules.Clipboard
import qs.Modules.KeybindsCheatSheet
import qs.Modules.Launcher
import qs.Modules.LockScreen
import qs.Modules.PackageManager
import qs.Modules.Settings
import qs.Modules.WallpaperSelector

Item {
    id: root

    // Pass the one live notification service instance to the Settings window.
    property var notificationService: null

    // Bar & media sockets — hosted by the active bar style overlay
    // (IslandBar / ConvexDesktop / GamingOverlay), never by standalone windows.

    // Application & drawer widgets
    WidgetLoader {
        widgetId: "launcher"

        sourceComponent: Component {
            Launcher {
            }

        }

    }

    WidgetLoader {
        widgetId: "clipboard"

        sourceComponent: Component {
            Clipboard {
            }

        }

    }

    WidgetLoader {
        widgetId: "wallpaper"

        sourceComponent: Component {
            WallpaperSelector {
            }

        }

    }

    // Standalone application windows
    WidgetLoader {
        widgetId: "veyra_keybinds"
        exclusive: false

        sourceComponent: Component {
            KeybindsCheatSheet {
            }

        }

    }

    WidgetLoader {
        widgetId: "veyra_settings"
        exclusive: false

        sourceComponent: Component {
            Settings {
                notificationService: root.notificationService
            }

        }

    }

    WidgetLoader {
        widgetId: "packagemanager"
        exclusive: false

        sourceComponent: Component {
            PackageManager {
            }

        }

    }

    LockScreen {
        id: lockScreen
    }

}
