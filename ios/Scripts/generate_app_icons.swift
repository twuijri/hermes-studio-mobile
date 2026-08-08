#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct IconSpec {
    let name: String
    let pixels: Int
}

private let specs = [
    IconSpec(name: "AppIcon20x20.png", pixels: 20),
    IconSpec(name: "AppIcon20x20@2x.png", pixels: 40),
    IconSpec(name: "AppIcon20x20@3x.png", pixels: 60),
    IconSpec(name: "AppIcon29x29.png", pixels: 29),
    IconSpec(name: "AppIcon29x29@2x.png", pixels: 58),
    IconSpec(name: "AppIcon29x29@3x.png", pixels: 87),
    IconSpec(name: "AppIcon40x40.png", pixels: 40),
    IconSpec(name: "AppIcon40x40@2x.png", pixels: 80),
    IconSpec(name: "AppIcon40x40@3x.png", pixels: 120),
    IconSpec(name: "AppIcon60x60@2x.png", pixels: 120),
    IconSpec(name: "AppIcon60x60@3x.png", pixels: 180),
    IconSpec(name: "AppIcon76x76.png", pixels: 76),
    IconSpec(name: "AppIcon76x76@2x.png", pixels: 152),
    IconSpec(name: "AppIcon83.5x83.5@2x.png", pixels: 167),
    IconSpec(name: "AppIcon1024.png", pixels: 1024),
]

private let background = CGColor(red: 0.035, green: 0.067, blue: 0.145, alpha: 1)
private let white = CGColor(red: 0.995, green: 0.995, blue: 1, alpha: 1)
private let purple = CGColor(red: 0.396, green: 0.278, blue: 0.961, alpha: 1)

private func stroke(_ points: [CGPoint], in context: CGContext) {
    guard let first = points.first else { return }
    context.beginPath()
    context.move(to: first)
    for point in points.dropFirst() { context.addLine(to: point) }
    context.strokePath()
}

private func render(pixels: Int) -> CGImage? {
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: pixels * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }

    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)
    context.setFillColor(background)
    context.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))

    let scale = CGFloat(pixels) / 108
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 108)
    context.scaleBy(x: 1, y: -1)

    context.setStrokeColor(white)
    context.setLineWidth(9)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    stroke([CGPoint(x: 54, y: 24), CGPoint(x: 54, y: 47)], in: context)
    stroke([CGPoint(x: 38, y: 38), CGPoint(x: 38, y: 52), CGPoint(x: 25, y: 63)], in: context)
    stroke([CGPoint(x: 70, y: 38), CGPoint(x: 70, y: 52), CGPoint(x: 83, y: 63)], in: context)
    stroke([CGPoint(x: 31, y: 76), CGPoint(x: 50, y: 64), CGPoint(x: 58, y: 64), CGPoint(x: 77, y: 76)], in: context)

    // The navy clearance is intentional brand geometry: the orchestration core
    // is an independent element and must never visually merge with the agents.
    context.setFillColor(background)
    context.fillEllipse(in: CGRect(x: 44, y: 44, width: 20, height: 20))
    context.setFillColor(purple)
    context.fillEllipse(in: CGRect(x: 48, y: 48, width: 12, height: 12))

    return context.makeImage()
}

private func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "HermesStudio/Resources", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for spec in specs {
    guard let image = render(pixels: spec.pixels) else { throw CocoaError(.fileWriteUnknown) }
    try write(image, to: output.appendingPathComponent(spec.name))
}
