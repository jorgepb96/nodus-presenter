import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

@main struct GenerateIcon {
    static func main() {
        let output = CommandLine.arguments[1]
        let dark = CommandLine.arguments.contains("--dark")
        let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                                bytesPerRow: 1024 * 4, space: NodusBrand.colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
            CGColor(colorSpace: NodusBrand.colorSpace, components: [red, green, blue, 1])!
        }
        let colors = dark ? [color(0.10, 0.09, 0.13), color(0.04, 0.04, 0.06)]
                          : [color(0.99, 0.98, 1), color(0.91, 0.88, 0.98)]
        let background = CGGradient(colorsSpace: NodusBrand.colorSpace,
                                    colors: colors as CFArray, locations: [0, 1])!
        // Same top-left coordinate system as the SwiftUI Canvas.
        context.translateBy(x: 0, y: 1024)
        context.scaleBy(x: 1, y: -1)
        context.drawLinearGradient(background, start: CGPoint(x: 150, y: 0), end: CGPoint(x: 850, y: 1024),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        NodusBrand.drawDisplay(in: context, size: 1024,
                              accent: dark ? NodusBrand.RGB.violet.shade(0.32) : .violet)
        let image = context.makeImage()!
        let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL,
                                                          UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        precondition(CGImageDestinationFinalize(destination), "Could not save icon")
    }
}
