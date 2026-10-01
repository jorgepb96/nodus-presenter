import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let output = CommandLine.arguments[1]
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 1024 * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: 1)
}
let background = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(0.99, 0.98, 1), color(0.91, 0.88, 0.98)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(background, start: CGPoint(x: 150, y: 1024), end: CGPoint(x: 850, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
context.setStrokeColor(color(0.54, 0.36, 0.96)); context.setLineWidth(25)
context.addPath(CGPath(roundedRect: CGRect(x: 160, y: 248, width: 704, height: 540), cornerWidth: 64, cornerHeight: 64, transform: nil))
context.strokePath()
context.setLineCap(.round)
context.move(to: CGPoint(x: 512, y: 248)); context.addLine(to: CGPoint(x: 512, y: 184))
context.move(to: CGPoint(x: 376, y: 177)); context.addLine(to: CGPoint(x: 648, y: 177)); context.strokePath()
// Original connected-N geometry: M18 48V16L46 48V16, with four circular nodes.
let points = [CGPoint(x: 372, y: 378), CGPoint(x: 372, y: 698), CGPoint(x: 652, y: 378), CGPoint(x: 652, y: 698)]
let mark = CGMutablePath(); mark.move(to: points[0]); points.dropFirst().forEach { mark.addLine(to: $0) }
context.saveGState()
context.addPath(mark.copy(strokingWithWidth: 65, lineCap: .round, lineJoin: .round, miterLimit: 10))
context.clip()
let violet = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [color(0.77, 0.71, 0.99), color(0.54, 0.36, 0.96), color(0.30, 0.11, 0.58)] as CFArray,
    locations: [0, 0.45, 1])!
context.drawLinearGradient(violet, start: points[1], end: points[2], options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
context.restoreGState()
let nodeColors = [color(0.54, 0.36, 0.96), color(0.77, 0.71, 0.99), color(0.49, 0.23, 0.93), color(0.30, 0.11, 0.58)]
for (point, fill) in zip(points, nodeColors) {
    context.setFillColor(fill); context.fillEllipse(in: CGRect(x: point.x - 65, y: point.y - 65, width: 130, height: 130))
}
let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination), "Could not save icon")
