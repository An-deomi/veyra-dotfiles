import Qt5Compat.GraphicalEffects as GE
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Core
import qs.Core.Services

Item {
    id: root

    property bool hasFrame: true
    property bool isShellReady: false
    property int barHeight: Constants.size4Xl
    property string activeBarStyle: "convex"
    property int bezelSize: DisplayProfileService.gameModeActive ? 0 : Constants.sizeXs
    property int innerRadius: Constants.size4Xl
    property real fsTransitionProg: 1
    property bool enableTransitionAnim: false
    property real expandOffset: (hasFrame && isShellReady && fsTransitionProg > 0.01) ? 0 : 28
    property real topBezelProg: 0
    property real leftW: 0
    property real centerX: 0
    property real centerW: 0
    property real rightW: 0
    property real centerHeight: barHeight
    property real centerBottomRadius: SettingsService.convexCornerRadius
    property real borderAngle: 0.785398
    readonly property color surfaceColor: Qt.rgba(Theme.opaqueBg.r, Theme.opaqueBg.g, Theme.opaqueBg.b, SettingsService.convexBackdropBlur ? SettingsService.convexBackgroundOpacity : 1)
    readonly property bool borderActive: SettingsService.convexBorderEnabled && root.hasFrame && root.bezelSize > 0
    readonly property bool useGradientBorder: root.borderActive && SettingsService.convexBorderColorMode === "gradient"
    readonly property color borderStrokeColor: SettingsService.convexBorderColorMode === "subtle" ? Theme.border : Theme.accent

    anchors.fill: parent
    opacity: (hasFrame && isShellReady) ? fsTransitionProg : 0
    visible: opacity > 0.001
    layer.enabled: false

    NumberAnimation on borderAngle {
        from: 0
        to: Math.PI * 2
        duration: Math.max(1500, SettingsService.hyprAnimBorderSpeed * 90)
        loops: Animation.Infinite
        running: root.useGradientBorder
            && root.visible
            && SettingsService.hyprAnimBorderSpin
            && HyprlandService.enableAnimations
            && !DisplayProfileService.gameModeActive
            && (SystemInfoService.effectivePowerProfile !== "power-saver")
    }

    function getBezelFillPath() {
        let W = Math.round(root.width);
        let H = Math.round(root.height);
        let b = root.bezelSize * root.fsTransitionProg;
        let r = root.innerRadius;
        let off = root.expandOffset;
        let topY = root.barHeight + (root.barHeight * root.topBezelProg) * root.fsTransitionProg;
        let inX = b - off;
        let inY = topY - off;
        let inW = W - 2 * b + 2 * off;
        let inH = H - topY - b + 2 * off;
        if (W <= 0 || H <= 0 || inW <= 0 || inH <= 0)
            return "";

        let k = r * 0.552285;
        let outer = `M 0 ${topY} L ${W} ${topY} L ${W} ${H} L 0 ${H} Z `;
        let inner = `M ${inX} ${inY + r} `
            + `L ${inX} ${inY + inH - r} `
            + `C ${inX} ${inY + inH - r + k}, ${inX + r - k} ${inY + inH}, ${inX + r} ${inY + inH} `
            + `L ${inX + inW - r} ${inY + inH} `
            + `C ${inX + inW - r + k} ${inY + inH}, ${inX + inW} ${inY + inH - r + k}, ${inX + inW} ${inY + inH - r} `
            + `L ${inX + inW} ${inY + r} `
            + `C ${inX + inW} ${inY + r - k}, ${inX + inW - r + k} ${inY}, ${inX + inW - r} ${inY} `
            + `L ${inX + r} ${inY} `
            + `C ${inX + r - k} ${inY}, ${inX} ${inY + r - k}, ${inX} ${inY + r} Z`;
        return outer + inner;
    }

    function getUnifiedBorderPath() {
        let W = Math.round(root.width);
        let H = Math.round(root.height);
        let b = root.bezelSize * root.fsTransitionProg;
        let r = root.innerRadius;
        let off = root.expandOffset;
        let topY = root.barHeight + (root.barHeight * root.topBezelProg) * root.fsTransitionProg;
        let lW = root.leftW;
        let rW = root.rightW;
        let cX = root.centerX;
        let cW = root.centerW;
        let rawCenterH = root.centerHeight;
        let rawCenterBr = root.centerBottomRadius;
        let tb = SettingsService.convexTopInset;
        let fw = SettingsService.convexNotchFlare;
        let br = SettingsService.convexCornerRadius;
        let inX = b - off;
        let inY = topY - off;
        let inW = W - 2 * b + 2 * off;
        let inH = H - topY - b + 2 * off;
        if (W <= 0 || H <= 0 || inW <= 0 || inH <= 0)
            return "";

        let k = r * 0.552285;
        if (lW <= 0 || rW <= 0 || cW <= 0) {
            return `M ${inX} ${inY + r} `
                + `L ${inX} ${inY + inH - r} `
                + `C ${inX} ${inY + inH - r + k}, ${inX + r - k} ${inY + inH}, ${inX + r} ${inY + inH} `
                + `L ${inX + inW - r} ${inY + inH} `
                + `C ${inX + inW - r + k} ${inY + inH}, ${inX + inW} ${inY + inH - r + k}, ${inX + inW} ${inY + inH - r} `
                + `L ${inX + inW} ${inY + r} `
                + `C ${inX + inW} ${inY + r - k}, ${inX + inW - r + k} ${inY}, ${inX + inW - r} ${inY} `
                + `L ${inX + r} ${inY} `
                + `C ${inX + r - k} ${inY}, ${inX} ${inY + r - k}, ${inX} ${inY + r} Z`;
        }

        let bh = inY;
        let fh = Math.max(0, fw - 2);
        let cH = Math.max(bh, rawCenterH);
        let centerR = rawCenterBr > 0 ? rawCenterBr : br;

        let sideSpan = Math.max(0, bh - tb);
        let sideScale = (br + fh > sideSpan && (br + fh) > 0) ? (sideSpan / (br + fh)) : 1;
        let sBr = br * sideScale;
        let sFh = fh * sideScale;

        let centerSpan = Math.max(0, cH - tb);
        let centerScale = (centerR + fh > centerSpan && (centerR + fh) > 0) ? (centerSpan / (centerR + fh)) : 1;
        let cBr = centerR * centerScale;
        let cFh = fh * centerScale;

        let leftCornerStart = Math.max(inX, lW - fw - sBr);
        let rL = Math.min(r, Math.max(0, leftCornerStart - inX));
        let kL = rL * 0.552285;

        let rX = W - rW;
        let rightCornerEnd = Math.min(inX + inW, rX + fw + sBr);
        let rR = Math.min(r, Math.max(0, (inX + inW) - rightCornerEnd));
        let kR = rR * 0.552285;

        let p = `M ${inX} ${inY + rL} `;
        // 1. Left bezel inner edge -> bottom-left corner -> bottom bezel -> bottom-right corner -> right bezel inner edge
        p += `L ${inX} ${inY + inH - r} `;
        p += `C ${inX} ${inY + inH - r + k}, ${inX + r - k} ${inY + inH}, ${inX + r} ${inY + inH} `;
        p += `L ${inX + inW - r} ${inY + inH} `;
        p += `C ${inX + inW - r + k} ${inY + inH}, ${inX + inW} ${inY + inH - r + k}, ${inX + inW} ${inY + inH - r} `;
        p += `L ${inX + inW} ${inY + rR} `;
        // 2. Top-right bezel corner smoothly connecting into right bar notch bottom
        p += `C ${inX + inW} ${inY + rR - kR}, ${inX + inW - rR + kR} ${inY}, ${inX + inW - rR} ${inY} `;
        p += `L ${rightCornerEnd} ${bh} `;
        // 3. Right bar notch inner corner & shoulder flare up to Bridge 2
        p += `C ${rX + fw + sBr * 0.45} ${bh}, ${rX + fw} ${bh - sBr * 0.45}, ${rX + fw} ${bh - sBr} `;
        if (bh - sBr > sFh + tb + 0.01)
            p += `L ${rX + fw} ${sFh + tb} `;

        p += `C ${rX + fw} ${sFh * 0.45 + tb}, ${rX + fw * 0.55} ${tb}, ${rX} ${tb} `;
        // 4. Bridge 2
        p += `L ${cX + cW} ${tb} `;
        // 5. Center bar notch (right shoulder -> bottom -> left shoulder)
        p += `C ${cX + cW - fw * 0.55} ${tb}, ${cX + cW - fw} ${cFh * 0.45 + tb}, ${cX + cW - fw} ${cFh + tb} `;
        if (cH - cBr > cFh + tb + 0.01)
            p += `L ${cX + cW - fw} ${cH - cBr} `;

        p += `C ${cX + cW - fw} ${cH - cBr * 0.45}, ${cX + cW - fw - cBr * 0.45} ${cH}, ${cX + cW - fw - cBr} ${cH} `;
        p += `L ${cX + fw + cBr} ${cH} `;
        p += `C ${cX + fw + cBr * 0.45} ${cH}, ${cX + fw} ${cH - cBr * 0.45}, ${cX + fw} ${cH - cBr} `;
        if (cH - cBr > cFh + tb + 0.01)
            p += `L ${cX + fw} ${cFh + tb} `;

        p += `C ${cX + fw} ${cFh * 0.45 + tb}, ${cX + fw * 0.55} ${tb}, ${cX} ${tb} `;
        // 6. Bridge 1
        p += `L ${lW} ${tb} `;
        // 7. Left bar notch shoulder flare & inner corner down to left bar notch bottom
        p += `C ${lW - fw * 0.55} ${tb}, ${lW - fw} ${sFh * 0.45 + tb}, ${lW - fw} ${sFh + tb} `;
        if (bh - sBr > sFh + tb + 0.01)
            p += `L ${lW - fw} ${bh - sBr} `;

        p += `C ${lW - fw} ${bh - sBr * 0.45}, ${lW - fw - sBr * 0.45} ${bh}, ${leftCornerStart} ${bh} `;
        p += `L ${inX + rL} ${inY} `;
        // 8. Top-left bezel corner back to left bezel inner edge
        p += `C ${inX + rL - kL} ${inY}, ${inX} ${inY + rL - kL}, ${inX} ${inY + rL} Z`;
        return p;
    }

    Shape {
        id: bezelFillShape

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.surfaceColor
            fillRule: ShapePath.OddEvenFill

            PathSvg {
                path: root.getBezelFillPath()
            }

        }

    }

    Shape {
        id: unifiedBorderShape

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real dx: Math.cos(root.borderAngle) * cx
        readonly property real dy: Math.sin(root.borderAngle) * cy

        anchors.fill: parent
        visible: root.borderActive && SettingsService.convexBorderWidth > 0
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: root.useGradientBorder && visible
        layer.smooth: true
        layer.samples: 4

        ShapePath {
            strokeWidth: root.borderActive ? SettingsService.convexBorderWidth : 0
            strokeColor: root.borderStrokeColor
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.getUnifiedBorderPath()
            }
        }

        layer.effect: GE.LinearGradient {
            start: Qt.point(unifiedBorderShape.cx - unifiedBorderShape.dx, unifiedBorderShape.cy - unifiedBorderShape.dy)
            end: Qt.point(unifiedBorderShape.cx + unifiedBorderShape.dx, unifiedBorderShape.cy + unifiedBorderShape.dy)
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.accent
                }

                GradientStop {
                    position: 1.0
                    color: Theme.accentComplementary
                }
            }
        }
    }

    Behavior on expandOffset {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: (root.hasFrame) ? Easing.OutCubic : Easing.InCubic
        }

    }

}
