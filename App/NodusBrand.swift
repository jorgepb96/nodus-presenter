import CoreGraphics
import Foundation

/// Canonical N from nodus/shared/nodusMark.json and src/dockIcon.ts.
/// Shared by the SwiftUI logo and AppIcon generator; coordinates use a top-left origin.
enum NodusBrand {
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    struct RGB {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        func shade(_ amount: CGFloat) -> RGB {
            let target: CGFloat = amount >= 0 ? 1 : 0
            let ratio = abs(amount)
            func mix(_ channel: CGFloat) -> CGFloat {
                (channel * 255 + (target * 255 - channel * 255) * ratio).rounded() / 255
            }
            return RGB(red: mix(red), green: mix(green), blue: mix(blue))
        }

        var color: CGColor { CGColor(colorSpace: NodusBrand.colorSpace, components: [red, green, blue, 1])! }
        static let violet = RGB(red: 139 / 255, green: 92 / 255, blue: 246 / 255)
    }

    static func drawMark(in context: CGContext, rect: CGRect, accent: RGB) {
        let unit = min(rect.width, rect.height) / 64
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
        }
        let light = accent.shade(0.55), dark = accent.shade(-0.4)
        let path = CGMutablePath()
        path.move(to: point(18, 48))
        path.addLine(to: point(18, 16))
        path.addLine(to: point(46, 48))
        path.addLine(to: point(46, 16))
        context.saveGState()
        context.addPath(path.copy(strokingWithWidth: 6.5 * unit, lineCap: .round, lineJoin: .round, miterLimit: 10))
        context.clip()
        let gradient = CGGradient(colorsSpace: colorSpace,
            colors: [light.color, accent.color, dark.color] as CFArray, locations: [0, 0.45, 1])!
        context.drawLinearGradient(gradient, start: point(14, 10), end: point(50, 54),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()

        let nodes: [(CGFloat, CGFloat, RGB)] = [(18, 16, light), (18, 48, accent),
                                               (46, 48, accent.shade(-0.15)), (46, 16, dark)]
        let radius = 6.5 * unit
        for (x, y, color) in nodes {
            let center = point(x, y)
            context.setFillColor(color.color)
            context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        }
    }

    static func drawDisplay(in context: CGContext, size: CGFloat, accent: RGB) {
        let unit = size / 1024
        context.saveGState()
        context.setStrokeColor(accent.color)
        context.setLineWidth(25 * unit)
        context.setLineCap(.round)
        context.addPath(CGPath(roundedRect: CGRect(x: 160 * unit, y: 236 * unit,
                                                  width: 704 * unit, height: 540 * unit),
                               cornerWidth: 64 * unit, cornerHeight: 64 * unit, transform: nil))
        context.strokePath()
        context.move(to: CGPoint(x: 512 * unit, y: 776 * unit))
        context.addLine(to: CGPoint(x: 512 * unit, y: 840 * unit))
        context.move(to: CGPoint(x: 376 * unit, y: 847 * unit))
        context.addLine(to: CGPoint(x: 648 * unit, y: 847 * unit))
        context.strokePath()
        // Give the original nodes clear space inside the display.
        drawMark(in: context, rect: CGRect(x: 232 * unit, y: 226 * unit,
                                          width: 560 * unit, height: 560 * unit), accent: accent)
        context.restoreGState()
    }
}
