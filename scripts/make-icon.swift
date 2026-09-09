#!/usr/bin/env swift
// Draws Resources/AppIcon.icns.
//
// Run through `mise run icon`. The icon is a prompt panel floating on a dark
// squircle — the same shape the app actually puts on screen, which is the only
// thing it does. Drawn in code rather than kept as a binary asset so a palette
// change is a diff.

import AppKit

// macOS app icons sit inside their canvas rather than filling it; ~10% inset is
// what the system icons use.
let canvasInset: CGFloat = 0.10
let squircleRadius: CGFloat = 0.225  // fraction of the squircle's own width

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high
    let inset = size * canvasInset
    let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let plateRadius = plate.width * squircleRadius

    // Backing plate: a deep blue-black, lit slightly from the top.
    let plateShape = NSBezierPath(roundedRect: plate, xRadius: plateRadius, yRadius: plateRadius)
    NSGradient(colors: [NSColor(srgbRed: 0.16, green: 0.17, blue: 0.24, alpha: 1),
                        NSColor(srgbRed: 0.07, green: 0.07, blue: 0.11, alpha: 1)])?
        .draw(in: plateShape, angle: -90)

    // The prompt panel, inset within the plate.
    let panelInset = plate.width * 0.155
    let panel = plate.insetBy(dx: panelInset, dy: plate.height * 0.235)
    let panelRadius = panel.height * 0.20
    NSColor(srgbRed: 0.96, green: 0.96, blue: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: panel, xRadius: panelRadius, yRadius: panelRadius).fill()

    // Two text lines: a long title and a shorter message.
    let lineHeight = panel.height * 0.11
    let lineInset = panel.width * 0.10
    func line(width fraction: CGFloat, fromTop offset: CGFloat, gray: CGFloat) {
        let rect = NSRect(x: panel.minX + lineInset,
                          y: panel.maxY - panel.height * offset - lineHeight,
                          width: (panel.width - lineInset * 2) * fraction,
                          height: lineHeight)
        NSColor(white: gray, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
    }
    line(width: 0.78, fromTop: 0.17, gray: 0.13)
    line(width: 0.52, fromTop: 0.38, gray: 0.62)

    // The primary button, in the same blue the default theme's accent uses.
    let buttonWidth = panel.width * 0.40
    let buttonHeight = panel.height * 0.22
    let button = NSRect(x: panel.maxX - lineInset - buttonWidth,
                        y: panel.minY + panel.height * 0.14,
                        width: buttonWidth, height: buttonHeight)
    NSColor(srgbRed: 0.18, green: 0.44, blue: 0.93, alpha: 1).setFill()
    NSBezierPath(roundedRect: button, xRadius: buttonHeight * 0.34, yRadius: buttonHeight * 0.34).fill()

    return image
}

func writePNG(_ image: NSImage, to path: String) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "make-icon", code: 1)
    }
    try png.write(to: URL(fileURLWithPath: path))
}

let iconset = "PrettyPrompt.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try writePNG(draw(size: CGFloat(base)), to: "\(iconset)/icon_\(base)x\(base).png")
    try writePNG(draw(size: CGFloat(base * 2)), to: "\(iconset)/icon_\(base)x\(base)@2x.png")
}
print("✓ \(iconset)")
