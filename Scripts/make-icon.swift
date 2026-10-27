#!/usr/bin/env swift
// Draws the Tabby icon. Run from the project root: ./Scripts/make-icon.swift
// Writes Resources/AppIcon.icns, Resources/icon.png and the site icons.
import Cocoa

let root = FileManager.default.currentDirectoryPath
let iconset = "\(root)/Resources/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: "\(root)/site", withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// A window card with cat ears: the front one is the app you're switching to.
func card(_ rect: NSRect, s: CGFloat, fill: NSColor, ears: Bool) -> NSBezierPath {
    fill.setFill()
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.045, yRadius: s * 0.045)
    path.fill()
    if ears {
        let w = rect.width * 0.24, h = rect.height * 0.32
        for (x, tip) in [(rect.minX + rect.width * 0.08, 0.38), (rect.maxX - rect.width * 0.08 - w, 0.62)] {
            let ear = NSBezierPath()
            ear.lineJoinStyle = .round
            ear.lineWidth = s * 0.02
            ear.move(to: NSPoint(x: x, y: rect.maxY - s * 0.03))
            ear.line(to: NSPoint(x: x + w * tip, y: rect.maxY + h))
            ear.line(to: NSPoint(x: x + w, y: rect.maxY - s * 0.03))
            ear.close()
            ear.fill()
            fill.setStroke()
            ear.stroke()
        }
    }
    return path
}

func draw(size: CGFloat) -> NSImage {
    let s = size
    return NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
        // macOS icon grid: the squircle sits inside a ~10% margin.
        let body = NSRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * 0.098, dy: s * 0.098)
        let squircle = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
        shadow.shadowBlurRadius = s * 0.03
        shadow.set()
        color(0xF26B2A).setFill()
        squircle.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGradient(colors: [color(0xFFB45C), color(0xF2662A)])!.draw(in: squircle, angle: -90)
        NSGraphicsContext.saveGraphicsState()
        squircle.addClip()
        NSGradient(colors: [NSColor(white: 1, alpha: 0.22), NSColor(white: 1, alpha: 0)])!
            .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // Two cards behind, one in front: the switcher, mid-⌥Tab.
        let w = body.width * 0.5, h = body.height * 0.36
        let front = NSRect(x: body.midX - w / 2 + s * 0.09, y: body.midY - h / 2 - s * 0.09, width: w, height: h)
        _ = card(front.offsetBy(dx: -s * 0.18, dy: s * 0.13), s: s, fill: NSColor(white: 1, alpha: 0.35), ears: false)
        _ = card(front.offsetBy(dx: -s * 0.09, dy: s * 0.065), s: s, fill: NSColor(white: 1, alpha: 0.55), ears: false)

        NSGraphicsContext.saveGraphicsState()
        let cardShadow = NSShadow()
        cardShadow.shadowColor = color(0x6B2208, 0.35)
        cardShadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
        cardShadow.shadowBlurRadius = s * 0.025
        cardShadow.set()
        // One transparency layer so the card and ears cast a single shadow.
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        _ = card(front, s: s, fill: .white, ears: true)
        ctx.endTransparencyLayer()
        NSGraphicsContext.restoreGraphicsState()

        // Title-bar dots and two content lines on the front card.
        let dot = s * 0.022
        for (i, hex) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
            color(UInt32(hex)).setFill()
            NSBezierPath(ovalIn: NSRect(x: front.minX + s * 0.03 + CGFloat(i) * dot * 1.6,
                                        y: front.maxY - s * 0.05, width: dot, height: dot)).fill()
        }
        color(0xF2662A).setFill()
        for i in -1...1 {
            let len = i == 0 ? s * 0.07 : s * 0.05
            NSBezierPath(roundedRect: NSRect(x: front.midX + CGFloat(i) * s * 0.04 - s * 0.009, y: front.maxY - len,
                                             width: s * 0.018, height: len), xRadius: s * 0.009, yRadius: s * 0.009).fill()
        }
        color(0xF2662A, 0.85).setFill()
        for (i, frac) in [0.7, 0.45].enumerated() {
            NSBezierPath(roundedRect: NSRect(x: front.minX + s * 0.03, y: front.minY + s * 0.035 + CGFloat(1 - i) * s * 0.045,
                                             width: (w - s * 0.06) * frac, height: s * 0.022),
                         xRadius: s * 0.011, yRadius: s * 0.011).fill()
        }
        return true
    }
}

func writePNG(_ image: NSImage, pixels: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let icon = draw(size: 1024)
for base in [16, 32, 128, 256, 512] {
    writePNG(icon, pixels: base, to: "\(iconset)/icon_\(base)x\(base).png")
    writePNG(icon, pixels: base * 2, to: "\(iconset)/icon_\(base)x\(base)@2x.png")
}
writePNG(icon, pixels: 1024, to: "\(root)/Resources/icon.png")
writePNG(icon, pixels: 512, to: "\(root)/site/icon-512.png")
writePNG(icon, pixels: 180, to: "\(root)/site/apple-touch-icon.png")
writePNG(icon, pixels: 32, to: "\(root)/site/favicon-32.png")

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "\(root)/Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
print("✓ Resources/AppIcon.icns")
