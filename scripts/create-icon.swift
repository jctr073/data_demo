#!/usr/bin/env swift

import AppKit
import Foundation

let outputURL: URL
if CommandLine.arguments.count > 1 {
    outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
} else {
    outputURL = URL(fileURLWithPath: ".build/app-icon.iconset")
}

try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let baseSize: CGFloat = 1024

func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, in size: CGFloat) -> NSRect {
    let scale = size / baseSize
    return NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat, in size: CGFloat) -> NSBezierPath {
    NSBezierPath(
        roundedRect: rect(x, y, width, height, in: size),
        xRadius: radius * size / baseSize,
        yRadius: radius * size / baseSize
    )
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: image.size).fill()

    let background = roundedRect(96, 96, 832, 832, 184, in: size)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.13, alpha: 1),
        NSColor(calibratedRed: 0.14, green: 0.20, blue: 0.23, alpha: 1)
    ])?.draw(in: background, angle: -32)

    NSColor(calibratedWhite: 1.0, alpha: 0.12).setStroke()
    background.lineWidth = max(2, size / 150)
    background.stroke()

    let panel = roundedRect(214, 236, 596, 552, 62, in: size)
    NSColor(calibratedRed: 0.17, green: 0.22, blue: 0.24, alpha: 1).setFill()
    panel.fill()

    let header = roundedRect(214, 680, 596, 108, 62, in: size)
    NSColor(calibratedRed: 0.55, green: 0.24, blue: 0.11, alpha: 1).setFill()
    header.fill()

    let headerMask = rect(214, 680, 596, 54, in: size)
    NSColor(calibratedRed: 0.55, green: 0.24, blue: 0.11, alpha: 1).setFill()
    headerMask.fill()

    NSColor(calibratedRed: 0.00, green: 0.43, blue: 0.72, alpha: 1).setStroke()
    panel.lineWidth = max(5, size / 84)
    panel.stroke()

    let tableIcon = rect(336, 712, 106, 56, in: size)
    NSColor(calibratedRed: 0.10, green: 0.55, blue: 0.88, alpha: 1).setStroke()
    NSBezierPath(rect: tableIcon).stroke()

    for x in [371, 406] {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: CGFloat(x) * size / baseSize, y: 712 * size / baseSize))
        line.line(to: NSPoint(x: CGFloat(x) * size / baseSize, y: 768 * size / baseSize))
        line.lineWidth = max(2, size / 170)
        line.stroke()
    }

    let rowDivider = NSBezierPath()
    rowDivider.move(to: NSPoint(x: 336 * size / baseSize, y: 740 * size / baseSize))
    rowDivider.line(to: NSPoint(x: 442 * size / baseSize, y: 740 * size / baseSize))
    rowDivider.lineWidth = max(2, size / 170)
    rowDivider.stroke()

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 64 * size / baseSize, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1)
    ]
    NSString(string: "Data").draw(
        at: NSPoint(x: 466 * size / baseSize, y: 704 * size / baseSize),
        withAttributes: titleAttributes
    )

    let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 38 * size / baseSize, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.13, green: 0.61, blue: 0.91, alpha: 1)
    ]
    let valueAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 46 * size / baseSize, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.86, alpha: 1)
    ]

    let rows: [(String, String, CGFloat)] = [
        ("123", "film_id", 592),
        ("A-Z", "title", 500),
        ("A-Z", "language", 408),
        ("123", "rate", 316)
    ]

    for row in rows {
        NSString(string: row.0).draw(
            at: NSPoint(x: 286 * size / baseSize, y: row.2 * size / baseSize),
            withAttributes: labelAttributes
        )
        NSString(string: row.1).draw(
            at: NSPoint(x: 392 * size / baseSize, y: (row.2 - 6) * size / baseSize),
            withAttributes: valueAttributes
        )
    }

    let shine = roundedRect(276, 742, 220, 24, 12, in: size)
    NSColor(calibratedWhite: 1, alpha: 0.22).setFill()
    shine.fill()

    let shadow = NSBezierPath(ovalIn: rect(246, 118, 532, 42, in: size))
    NSColor(calibratedWhite: 0, alpha: 0.22).setFill()
    shadow.fill()

    image.unlockFocus()
    return image
}

func writePNG(size: CGFloat, fileName: String) throws {
    let image = drawIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: outputURL.appendingPathComponent(fileName))
}

try writePNG(size: 16, fileName: "icon_16x16.png")
try writePNG(size: 32, fileName: "icon_16x16@2x.png")
try writePNG(size: 32, fileName: "icon_32x32.png")
try writePNG(size: 64, fileName: "icon_32x32@2x.png")
try writePNG(size: 128, fileName: "icon_128x128.png")
try writePNG(size: 256, fileName: "icon_128x128@2x.png")
try writePNG(size: 256, fileName: "icon_256x256.png")
try writePNG(size: 512, fileName: "icon_256x256@2x.png")
try writePNG(size: 512, fileName: "icon_512x512.png")
try writePNG(size: 1024, fileName: "icon_512x512@2x.png")
