#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count >= 7 else {
    fputs("usage: render_native_label.swift output width height font size text\n", stderr)
    exit(64)
}

let output = CommandLine.arguments[1]
guard let width = Int(CommandLine.arguments[2]),
      let height = Int(CommandLine.arguments[3]),
      let size = Double(CommandLine.arguments[5]) else {
    fputs("invalid dimensions or font size\n", stderr)
    exit(64)
}
let fontName = CommandLine.arguments[4]
let text = CommandLine.arguments[6]
let alignment = CommandLine.arguments.count > 7 ? CommandLine.arguments[7] : "right"
let scale = 2
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width * scale,
    pixelsHigh: height * scale,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
bitmap.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = alignment == "left" ? .left : .right
paragraph.lineBreakMode = .byTruncatingTail
let font = NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(
        calibratedRed: 23 / 255,
        green: 32 / 255,
        blue: 51 / 255,
        alpha: 1
    ),
    .paragraphStyle: paragraph,
]
(text as NSString).draw(
    in: NSRect(x: 0, y: 1, width: width, height: height - 1),
    withAttributes: attributes
)
NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fputs("could not encode PNG\n", stderr)
    exit(65)
}
try data.write(to: URL(fileURLWithPath: output), options: .atomic)
