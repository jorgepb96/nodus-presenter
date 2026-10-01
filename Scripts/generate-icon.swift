import AppKit
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
let canvas = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
NSColor(calibratedRed: 0.075, green: 0.06, blue: 0.14, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let screen = NSBezierPath(roundedRect: NSRect(x: 142, y: 230, width: 740, height: 578), xRadius: 80, yRadius: 80)
NSColor(calibratedRed: 0.78, green: 0.68, blue: 1, alpha: 1).setStroke(); screen.lineWidth = 28; screen.stroke()
let stand = NSBezierPath(); stand.move(to: NSPoint(x: 512, y: 230)); stand.line(to: NSPoint(x: 512, y: 166)); stand.move(to: NSPoint(x: 376, y: 153)); stand.line(to: NSPoint(x: 648, y: 153)); stand.lineWidth = 28; stand.lineCapStyle = .round; stand.stroke()
// Exact connected-N geometry from Nodus' vector logo, scaled inside the display.
let points = [NSPoint(x: 338,y: 375), NSPoint(x: 338,y: 695), NSPoint(x: 618,y: 375), NSPoint(x: 618,y: 695)]
let n = NSBezierPath(); n.move(to: points[0]); n.line(to: points[1]); n.line(to: points[2]); n.line(to: points[3]); n.lineWidth = 65; n.lineCapStyle = .round; n.lineJoinStyle = .round
NSColor(calibratedRed: 0.63, green: 0.43, blue: 0.98, alpha: 1).setStroke(); n.stroke()
NSColor(calibratedRed: 0.82, green: 0.73, blue: 1, alpha: 1).setFill()
for p in points { NSBezierPath(ovalIn: NSRect(x: p.x - 42, y: p.y - 42, width: 84, height: 84)).fill() }
NSGraphicsContext.restoreGraphicsState()
let bitmap = canvas
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
