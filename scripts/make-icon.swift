// Generates packaging/AppIcon.icns.
// Run:  swift scripts/make-icon.swift
// Draws a flat terracotta tile with the Island mark — a capsule with a text
// cursor set into it — writes a 1024px master PNG, then builds the .icns via
// sips + iconutil. Deliberately flat: no gradients, no glows.

import AppKit

let size = 1024
let workDir = FileManager.default.currentDirectoryPath
let packagingDir = "\(workDir)/packaging"
let iconsetDir = "\(packagingDir)/AppIcon.iconset"
let masterPNG = "\(packagingDir)/icon-1024.png"

let terracotta = NSColor(srgbRed: 0.706, green: 0.333, blue: 0.180, alpha: 1)

try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("could not create bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let s = CGFloat(size)
let center = CGPoint(x: s / 2, y: s / 2)

// Tile: macOS icons float inside the canvas rather than filling it.
let inset: CGFloat = s * 0.06
let tile = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
let corner = tile.width * 0.229
terracotta.setFill()
NSBezierPath(roundedRect: tile, xRadius: corner, yRadius: corner).fill()

// The mark: the island bar, and under it the two lines of text it feeds.
// Three flat shapes, so it still reads at 16px.
NSColor.white.setFill()

func capsule(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    let rect = CGRect(x: center.x + x - width / 2, y: center.y + y, width: width, height: height)
    NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2).fill()
}

// Nudged down so the group sits optically centred in the tile.
let drop = s * 0.028
capsule(x: 0, y: s * 0.055 - drop, width: s * 0.56, height: s * 0.185)
capsule(x: 0, y: -s * 0.075 - drop, width: s * 0.56, height: s * 0.055)
capsule(x: -s * 0.11, y: -s * 0.185 - drop, width: s * 0.34, height: s * 0.055)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png data") }
try png.write(to: URL(fileURLWithPath: masterPNG))
print("wrote \(masterPNG)")

// Build the iconset from the master.
let variants: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func run(_ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = args
    try! p.run()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else { fatalError("failed: \(args.joined(separator: " "))") }
}

for v in variants {
    run(["sips", "-z", "\(v.px)", "\(v.px)", masterPNG,
         "--out", "\(iconsetDir)/\(v.name).png"])
}
run(["iconutil", "-c", "icns", iconsetDir, "-o", "\(packagingDir)/AppIcon.icns"])
print("wrote \(packagingDir)/AppIcon.icns")

// The landing page uses a smaller copy of the same master.
run(["sips", "-z", "256", "256", masterPNG, "--out", "\(workDir)/site/icon.png"])
print("wrote \(workDir)/site/icon.png")
