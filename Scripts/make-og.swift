#!/usr/bin/env swift
// Draws the 1200×630 social preview at site/og.png. Run after make-icon.swift.
import Cocoa

let root = FileManager.default.currentDirectoryPath
let icon = NSImage(contentsOfFile: "\(root)/Resources/icon.png")!
let size = NSSize(width: 1200, height: 630)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 630, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let bg = NSColor(srgbRed: 1, green: 0.973, blue: 0.949, alpha: 1)
bg.setFill()
NSRect(origin: .zero, size: size).fill()
NSGradient(colors: [NSColor(srgbRed: 1, green: 0.706, blue: 0.361, alpha: 0.35), bg.withAlphaComponent(0)])!
    .draw(fromCenter: NSPoint(x: 300, y: 315), radius: 0, toCenter: NSPoint(x: 300, y: 315), radius: 420, options: [])

icon.draw(in: NSRect(x: 80, y: 115, width: 400, height: 400))

let ink = NSColor(srgbRed: 0.133, green: 0.09, blue: 0.059, alpha: 1)
let muted = NSColor(srgbRed: 0.478, green: 0.4, blue: 0.337, alpha: 1)
("Tabby" as NSString).draw(at: NSPoint(x: 520, y: 330), withAttributes: [
    .font: NSFont.systemFont(ofSize: 112, weight: .bold), .foregroundColor: ink, .kern: -3])
let sub = NSMutableParagraphStyle()
sub.lineSpacing = 6
("A minimal ⌥Tab app switcher\nfor macOS, with live previews." as NSString).draw(
    in: NSRect(x: 524, y: 180, width: 640, height: 140),
    withAttributes: [.font: NSFont.systemFont(ofSize: 40, weight: .medium), .foregroundColor: muted, .paragraphStyle: sub])

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(root)/site/og.png"))
print("✓ site/og.png")
