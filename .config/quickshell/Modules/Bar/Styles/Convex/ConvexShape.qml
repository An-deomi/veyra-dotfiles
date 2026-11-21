import Qt5Compat.GraphicalEffects as GE
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property bool enableShadow: true
    property color color: Theme.bg
    property color borderColor: "transparent"
    property real borderWidth: 0
    property bool useGradientBorder: false
    property real borderAngle: 0.785398
    property real flareWidth: Constants.sizeLg + 2
    property real flareHeight: Constants.sizeLg
    property real bottomRadius: Constants.sizeLg
    property real centerBottomRadius: bottomRadius
    property real topBezel: Constants.sizeXs
    property real baseHeight: 44
    property real leftW: 0
    property real centerX: 0
    property real centerW: 0
    property real rightW: 0
    property real centerHeight: height

    NumberAnimation on borderAngle {
        from: 0
        to: Math.PI * 2
        duration: Math.max(1500, SettingsService.hyprAnimBorderSpeed * 90)
        loops: Animation.Infinite
        running: root.useGradientBorder
            && root.borderWidth > 0
            && SettingsService.hyprAnimBorderSpin
            && HyprlandService.enableAnimations
            && !DisplayProfileService.gameModeActive
            && (SystemInfoService.effectivePowerProfile !== "power-saver")
    }

    function getInnerContour(w, h, lW, cX, cW, rW, tb, fw, fh, br, cH, baseH, cbr) {
        if (w <= 0 || h <= 0)
            return "";

        let bh = baseH > 0 ? baseH : h;
        let centerR = (cbr !== undefined && cbr > 0) ? cbr : br;
        let sideSpan = Math.max(0, bh - tb);
        let sideScale = (br + fh > sideSpan && (br + fh) > 0) ? (sideSpan / (br + fh)) : 1;
        let sBr = br * sideScale;
        let sFh = fh * sideScale;

        let centerSpan = Math.max(0, cH - tb);
        let centerScale = (centerR + fh > centerSpan && (centerR + fh) > 0) ? (centerSpan / (centerR + fh)) : 1;
        let cBr = centerR * centerScale;
        let cFh = fh * centerScale;

        let p = `L ${lW - fw - sBr} ${bh} `;
        p += `C ${lW - fw - sBr * 0.45} ${bh}, ${lW - fw} ${bh - sBr * 0.45}, ${lW - fw} ${bh - sBr} `;
        if (bh - sBr > sFh + tb + 0.01)
            p += `L ${lW - fw} ${sFh + tb} `;

        p += `C ${lW - fw} ${sFh * 0.45 + tb}, ${lW - fw * 0.55} ${tb}, ${lW} ${tb} `;
        // 2. Bridge 1
        p += `L ${cX} ${tb} `;
        // 3. Flare into center notch
        p += `C ${cX + fw * 0.55} ${tb}, ${cX + fw} ${cFh * 0.45 + tb}, ${cX + fw} ${cFh + tb} `;
        if (cH - cBr > cFh + tb + 0.01)
            p += `L ${cX + fw} ${cH - cBr} `;

        p += `C ${cX + fw} ${cH - cBr * 0.45}, ${cX + fw + cBr * 0.45} ${cH}, ${cX + fw + cBr} ${cH} `;
        // 4. Center notch bottom
        p += `L ${cX + cW - fw - cBr} ${cH} `;
        p += `C ${cX + cW - fw - cBr * 0.45} ${cH}, ${cX + cW - fw} ${cH - cBr * 0.45}, ${cX + cW - fw} ${cH - cBr} `;
        if (cH - cBr > cFh + tb + 0.01)
            p += `L ${cX + cW - fw} ${cFh + tb} `;

        p += `C ${cX + cW - fw} ${cFh * 0.45 + tb}, ${cX + cW - fw * 0.55} ${tb}, ${cX + cW} ${tb} `;
        // 5. Bridge 2
        let rX = w - rW;
        p += `L ${rX} ${tb} `;
        // 6. Flare into right notch
        p += `C ${rX + fw * 0.55} ${tb}, ${rX + fw} ${sFh * 0.45 + tb}, ${rX + fw} ${sFh + tb} `;
        if (bh - sBr > sFh + tb + 0.01)
            p += `L ${rX + fw} ${bh - sBr} `;

        p += `C ${rX + fw} ${bh - sBr * 0.45}, ${rX + fw + sBr * 0.45} ${bh}, ${rX + fw + sBr} ${bh} `;
        p += `L ${w} ${bh} `;
        return p;
    }

    function getPath(w, h, lW, cX, cW, rW, tb, fw, fh, br, cH, baseH, cbr) {
        if (w <= 0 || h <= 0)
            return "";

        let bh = baseH > 0 ? baseH : h;
        let contour = getInnerContour(w, h, lW, cX, cW, rW, tb, fw, fh, br, cH, baseH, cbr);
        return `M 0 0 L 0 ${bh} ` + contour + `L ${w} 0 Z`;
    }

    function getBorderPath(w, h, lW, cX, cW, rW, tb, fw, fh, br, cH, baseH, cbr) {
        if (w <= 0 || h <= 0)
            return "";

        let bh = baseH > 0 ? baseH : h;
        let contour = getInnerContour(w, h, lW, cX, cW, rW, tb, fw, fh, br, cH, baseH, cbr);
        return `M 0 ${bh} ` + contour;
    }

    Shape {
        id: visibleShape

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: root.enableShadow && HyprlandService.hyprShadow && root.opacity > 0.001
        layer.smooth: root.enableShadow
        layer.samples: root.enableShadow ? 4 : 1

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color

            PathSvg {
                path: root.getPath(root.width, root.height, root.leftW, root.centerX, root.centerW, root.rightW, root.topBezel, root.flareWidth, root.flareHeight, root.bottomRadius, root.centerHeight, root.baseHeight, root.centerBottomRadius)
            }

        }

        layer.effect: MultiEffect {
            shadowEnabled: root.enableShadow && HyprlandService.hyprShadow && !DisplayProfileService.gameModeActive && (SystemInfoService.effectivePowerProfile !== "power-saver") && root.opacity > 0.001
            shadowColor: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, Theme.isDark ? 1 : Math.min(1, Theme.shadow.a * 1.6))
            blurMax: HyprlandService.hyprShadowRange
            shadowBlur: 1
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
        }

    }

    Shape {
        id: borderShape

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real dx: Math.cos(root.borderAngle) * cx
        readonly property real dy: Math.sin(root.borderAngle) * cy

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height + 6
        visible: root.borderWidth > 0
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: root.useGradientBorder && root.borderWidth > 0
        layer.smooth: true
        layer.samples: 4

        ShapePath {
            strokeWidth: root.borderWidth
            strokeColor: root.borderColor
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.getBorderPath(root.width, root.height, root.leftW, root.centerX, root.centerW, root.rightW, root.topBezel, root.flareWidth, root.flareHeight, root.bottomRadius, root.centerHeight, root.baseHeight, root.centerBottomRadius)
            }
        }

        layer.effect: GE.LinearGradient {
            start: Qt.point(borderShape.cx - borderShape.dx, borderShape.cy - borderShape.dy)
            end: Qt.point(borderShape.cx + borderShape.dx, borderShape.cy + borderShape.dy)
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

    Behavior on color {
        ColorAnimation {
            duration: Constants.animNormal
        }

    }

}
