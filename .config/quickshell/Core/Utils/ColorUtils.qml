import QtQuick
pragma Singleton

QtObject {
    id: root

    function linearChannel(value) {
        return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
    }

    function relativeLuminance(value) {
        const c = Qt.color(value);
        return 0.2126 * linearChannel(c.r)
            + 0.7152 * linearChannel(c.g)
            + 0.0722 * linearChannel(c.b);
    }

    function contrastRatio(foreground, background) {
        const first = relativeLuminance(foreground);
        const second = relativeLuminance(background);
        const lighter = Math.max(first, second);
        const darker = Math.min(first, second);
        return (lighter + 0.05) / (darker + 0.05);
    }

    // Preserve the source hue where possible, moving only as far toward black
    // or white as required to meet the requested contrast against the surface.
    function ensureContrast(foreground, background, minimumRatio) {
        const fg = Qt.color(foreground);
        const bg = Qt.color(background);
        const minimum = minimumRatio === undefined ? 4.5 : minimumRatio;
        if (contrastRatio(fg, bg) >= minimum)
            return fg;

        const black = Qt.rgba(0, 0, 0, 1);
        const white = Qt.rgba(1, 1, 1, 1);
        const target = contrastRatio(black, bg) >= contrastRatio(white, bg) ? black : white;
        let low = 0;
        let high = 1;
        for (let i = 0; i < 24; i++) {
            const amount = (low + high) / 2;
            const mixed = Qt.rgba(
                fg.r + (target.r - fg.r) * amount,
                fg.g + (target.g - fg.g) * amount,
                fg.b + (target.b - fg.b) * amount,
                1
            );
            if (contrastRatio(mixed, bg) >= minimum)
                high = amount;
            else
                low = amount;
        }
        return Qt.rgba(
            fg.r + (target.r - fg.r) * high,
            fg.g + (target.g - fg.g) * high,
            fg.b + (target.b - fg.b) * high,
            1
        );
    }

    // The black/white text crossover is approximately WCAG relative luminance 0.179.
    function isDark(color) {
        return relativeLuminance(color) <= 0.179;
    }
}
