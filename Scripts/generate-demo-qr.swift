#!/usr/bin/env swift
import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

// Machine-readable QR generation: no network, credentials or image synthesis.
let payload = "nodus-presenter://demo"
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first
    ?? "AppStore/Demo/nodus-presenter-demo-qr.png")
let filter = CIFilter(name: "CIQRCodeGenerator")!
filter.setValue(Data(payload.utf8), forKey: "inputMessage")
filter.setValue("M", forKey: "inputCorrectionLevel")
guard let qr = filter.outputImage else { fatalError("Could not generate demo QR") }

let scale = 24
let quietZone = 4 * scale
let scaled = qr.transformed(by: CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale)))
guard let code = CIContext().createCGImage(scaled, from: scaled.extent) else {
    fatalError("Could not render demo QR")
}
let width = code.width + 2 * quietZone
let height = code.height + 2 * quietZone
guard let canvas = CGContext(data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Could not create QR canvas")
}
canvas.setFillColor(CGColor(gray: 1, alpha: 1))
canvas.fill(CGRect(x: 0, y: 0, width: width, height: height))
canvas.interpolationQuality = CGInterpolationQuality.none
canvas.draw(code, in: CGRect(x: quietZone, y: quietZone, width: code.width, height: code.height))
guard let image = canvas.makeImage() else { fatalError("Could not finish QR image") }
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not write PNG")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not save PNG") }

// Decode the saved file, including its orientation, to verify the final artifact.
let request = VNDetectBarcodesRequest()
request.symbologies = [.qr]
try VNImageRequestHandler(url: output).perform([request])
guard request.results?.count == 1, request.results?.first?.payloadStringValue == payload else {
    fatalError("Saved QR does not decode to the expected demo link")
}
print("Verified \(width)×\(height) PNG: \(output.path)")
print("Payload: \(payload)")
