// Generates site/og.png — the 1200×630 social preview card.
// Run:  swift scripts/make-og.swift   (after scripts/make-icon.swift)
// Flat shapes and type only: no gradients, no glows.

import AppKit

let width: CGFloat = 1200
let height: CGFloat = 630
let workDir = FileManager.default.currentDirectoryPath

// MARK: - Palette

func hex(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: alpha
    )
}

let background = hex(0x0E1013)
let surface = hex(0x1A1D23)
let surfaceDim = hex(0x14171B)
let line = hex(0x272B33)
let chipFill = hex(0x23272E)
let ink = hex(0xE8E9EC)
let muted = hex(0x99A0AC)
let accent = hex(0xE08B5E)

// MARK: - Canvas (top-left origin, like CSS)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("could not create bitmap") }

guard let base = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("no context") }
let cg = base.cgContext
cg.translateBy(x: 0, y: height)
cg.scaleBy(x: 1, y: -1)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

func fill(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 0) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func stroke(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 0, lineWidth: CGFloat = 1) {
    color.setStroke()
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2), xRadius: radius, yRadius: radius)
    path.lineWidth = lineWidth
    path.stroke()
}

func attributes(
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = ink,
    tracking: CGFloat = 0,
    monospaced: Bool = false
) -> [NSAttributedString.Key: Any] {
    [
        .font: monospaced
            ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: tracking,
    ]
}

@discardableResult
func text(_ string: String, at point: CGPoint, _ attrs: [NSAttributedString.Key: Any]) -> CGSize {
    let attributed = NSAttributedString(string: string, attributes: attrs)
    attributed.draw(at: point)
    return attributed.size()
}

func measure(_ string: String, _ attrs: [NSAttributedString.Key: Any]) -> CGSize {
    NSAttributedString(string: string, attributes: attrs).size()
}

fill(CGRect(x: 0, y: 0, width: width, height: height), background)

// MARK: - Left column

let left: CGFloat = 80

if let icon = NSImage(contentsOfFile: "\(workDir)/packaging/icon-1024.png") {
    icon.draw(in: CGRect(x: left, y: 128, width: 88, height: 88))
}

// Eyebrow
let eyebrowAttrs = attributes(size: 12, weight: .semibold, color: accent, tracking: 1.6)
let eyebrow = "MACOS FLOATING WIDGET"
let eyebrowSize = measure(eyebrow, eyebrowAttrs)
let eyebrowBox = CGRect(x: left, y: 250, width: eyebrowSize.width + 26, height: 30)
stroke(eyebrowBox, accent.withAlphaComponent(0.55), radius: 15)
text(eyebrow, at: CGPoint(x: left + 13, y: 250 + (30 - eyebrowSize.height) / 2), eyebrowAttrs)

// Headline
let headlineAttrs = attributes(size: 31, weight: .bold, color: ink, tracking: -0.4)
text("Click a snippet. It lands in", at: CGPoint(x: left, y: 306), headlineAttrs)
text("whatever you're typing in.", at: CGPoint(x: left, y: 348), headlineAttrs)

// Install command
let commandAttrs = attributes(size: 14.5, weight: .regular, color: ink, monospaced: true)
let promptAttrs = attributes(size: 14.5, weight: .regular, color: muted, monospaced: true)
let command = "brew install --cask souhaibbenfarhat/tap/island"
let commandSize = measure("$ " + command, commandAttrs)
let commandBox = CGRect(x: left, y: 412, width: commandSize.width + 36, height: 42)
fill(commandBox, surface, radius: 10)
let promptWidth = measure("$ ", promptAttrs).width
text("$ ", at: CGPoint(x: left + 18, y: 412 + (42 - commandSize.height) / 2), promptAttrs)
text(command, at: CGPoint(x: left + 18 + promptWidth, y: 412 + (42 - commandSize.height) / 2), commandAttrs)

text(
    "Free · Open source · Native SwiftUI",
    at: CGPoint(x: left, y: 478),
    attributes(size: 15, color: muted)
)


func islandMark(x: CGFloat, centerY: CGFloat, width markWidth: CGFloat) {
    let gap = markWidth * 0.115
    let capsuleHeight = markWidth * 0.42
    let lineHeight = markWidth * 0.11
    let total = capsuleHeight + lineHeight * 2 + gap * 2
    var y = centerY - total / 2
    ink.withAlphaComponent(0.85).setFill()
    NSBezierPath(roundedRect: CGRect(x: x, y: y, width: markWidth, height: capsuleHeight),
                 xRadius: capsuleHeight / 2, yRadius: capsuleHeight / 2).fill()
    y += capsuleHeight + gap
    NSBezierPath(roundedRect: CGRect(x: x, y: y, width: markWidth, height: lineHeight),
                 xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
    y += lineHeight + gap
    NSBezierPath(roundedRect: CGRect(x: x, y: y, width: markWidth * 0.62, height: lineHeight),
                 xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
}

// MARK: - Right column: the island, and the field it types into

let right: CGFloat = 898 // centre of the right column

// The flower: the collapsed island ringed by its items.
let ringCentre = CGPoint(x: right, y: 215)
let ringRadius: CGFloat = 68
let petalDiameter: CGFloat = 42

let petals: [(caption: String, colour: NSColor)] = [
    ("E", hex(0xB4552E)),
    ("S", hex(0x2F7069)),
    ("T", hex(0xB8862B)),
    ("TI", hex(0x4C4A8C)),
    ("A", hex(0x6E7F3F)),
    ("WE", hex(0x7A3F63)),
]

let petalAttrs = attributes(size: 14, weight: .semibold, color: .white)

for (index, petal) in petals.enumerated() {
    // Start at the top and work clockwise. The context is flipped, so y grows
    // downwards and -90° points up.
    let angle = (-90 + 60 * CGFloat(index)) * .pi / 180
    let centre = CGPoint(
        x: ringCentre.x + cos(angle) * ringRadius,
        y: ringCentre.y + sin(angle) * ringRadius
    )
    let circle = CGRect(
        x: centre.x - petalDiameter / 2,
        y: centre.y - petalDiameter / 2,
        width: petalDiameter,
        height: petalDiameter
    )
    petal.colour.setFill()
    NSBezierPath(ovalIn: circle).fill()
    stroke(circle, NSColor.white.withAlphaComponent(0.22), radius: petalDiameter / 2)

    let size = measure(petal.caption, petalAttrs)
    text(
        petal.caption,
        at: CGPoint(x: centre.x - size.width / 2, y: centre.y - size.height / 2),
        petalAttrs
    )
}

// The pill itself, sitting in the middle of the ring.
let pill = CGRect(x: ringCentre.x - 22, y: ringCentre.y - 17, width: 44, height: 34)
fill(pill, surface, radius: 17)
stroke(pill, line, radius: 17)
islandMark(x: pill.midX - 10, centerY: pill.midY, width: 20)

// The connector: text travelling from the flower down into the field.
let ringBottom = ringCentre.y + ringRadius + petalDiameter / 2
// A touch lighter than the panel borders, or the dashes vanish into the
// background at social-preview size.
hex(0x3A404B).setStroke()
let connector = NSBezierPath()
connector.move(to: CGPoint(x: right, y: ringBottom + 10))
connector.line(to: CGPoint(x: right, y: ringBottom + 48))
connector.lineWidth = 1.5
connector.setLineDash([4, 5], count: 2, phase: 0)
connector.stroke()

accent.setFill()
let arrow = NSBezierPath()
arrow.move(to: CGPoint(x: right, y: ringBottom + 58))
arrow.line(to: CGPoint(x: right - 5.5, y: ringBottom + 48))
arrow.line(to: CGPoint(x: right + 5.5, y: ringBottom + 48))
arrow.close()
arrow.fill()

// The field being typed into
let field = CGRect(x: right - 210, y: 374, width: 420, height: 140)
fill(field, surfaceDim, radius: 14)
stroke(field, line, radius: 14)

text(
    "TO",
    at: CGPoint(x: field.minX + 22, y: field.minY + 24),
    attributes(size: 10.5, weight: .semibold, color: muted, tracking: 1.5)
)

let valueAttrs = attributes(size: 19, weight: .regular, color: ink)
let valueSize = measure("you@example.com", valueAttrs)
text("you@example.com", at: CGPoint(x: field.minX + 22, y: field.minY + 50), valueAttrs)
fill(
    CGRect(x: field.minX + 26 + valueSize.width, y: field.minY + 50, width: 2, height: valueSize.height),
    accent
)

// Two dim lines standing in for the rest of the message.
fill(CGRect(x: field.minX + 22, y: field.minY + 96, width: 220, height: 7), hex(0x272B33), radius: 3.5)
fill(CGRect(x: field.minX + 22, y: field.minY + 114, width: 148, height: 7), hex(0x21252B), radius: 3.5)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png data") }
try png.write(to: URL(fileURLWithPath: "\(workDir)/site/og.png"))
print("wrote \(workDir)/site/og.png")
