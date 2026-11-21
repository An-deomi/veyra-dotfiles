pragma Singleton
import QtQuick
import qs.Core

// Veyra chrome tokens: radii, borders, focus rings and accent tints.
// Reference these instead of inventing per-module values.
//
// Accent discipline (see docs/DESIGN.md):
//   accent              -> interactive elements, selection, focus
//   accentComplementary -> attention/secondary emphasis, one per screen max
QtObject {
    id: root

    // Radii
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 16
    readonly property int radiusXl: 22

    // Borders
    readonly property int borderWidth: 1
    readonly property color borderColor: Theme.border

    // Focus ring (keyboard focus, search fields, list views)
    readonly property int focusRingWidth: 2
    readonly property color focusRingColor: Theme.accent

    // Accent tints for hover / selected backgrounds
    readonly property color accentTint: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
    readonly property color accentTintStrong: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
    readonly property color attention: Theme.accentComplementary
    readonly property color attentionTint: Qt.rgba(Theme.accentComplementary.r, Theme.accentComplementary.g, Theme.accentComplementary.b, 0.14)

    // Elevation
    readonly property color shadowColor: Theme.shadow
}
