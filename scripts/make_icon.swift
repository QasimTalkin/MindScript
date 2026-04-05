#!/usr/bin/env swift
/// Generates MindScript app icon at all required macOS sizes.
/// Run via: swift scripts/make_icon.swift <output_dir>
import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconSize: CGFloat = 1024

// ── Draw white SF Symbol masked onto a transparent background ─────────────────
func whiteSymbol(named name: String, pointSize: CGFloat) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                        .withSymbolConfiguration(cfg) else { return nil }

    // Fill white rect, clip to the symbol's shape using .destinationIn
    return NSImage(size: sym.size, flipped: false) { rect in
        NSColor.white.withAlphaComponent(0.93).setFill()
        NSBezierPath.fill(rect)
        sym.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
        return true
    }
}

// ── Build the 1024×1024 master icon ───────────────────────────────────────────
let master = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { bounds in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // Rounded-rect clip (macOS icon style: 22.5% corner radius)
    let radius = iconSize * 0.225
    let path = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Background: dark navy → deep purple gradient (top-left to bottom-right)
    let space = CGColorSpaceCreateDeviceRGB()
    let colors: CFArray = [
        CGColor(red: 0.055, green: 0.067, blue: 0.200, alpha: 1.0),   // navy
        CGColor(red: 0.220, green: 0.098, blue: 0.475, alpha: 1.0),   // deep purple
    ] as CFArray
    let stops: [CGFloat] = [0, 1]
    let gradient = CGGradient(colorsSpace: space, colors: colors, locations: stops)!
    ctx.drawLinearGradient(gradient,
        start: CGPoint(x: 0, y: iconSize),
        end:   CGPoint(x: iconSize, y: 0),
        options: [])

    // Subtle inner glow ring for depth
    let glowRadius = iconSize * 0.44
    let cx = iconSize / 2, cy = iconSize / 2
    let glowColors: CFArray = [
        CGColor(red: 0.5, green: 0.35, blue: 1.0, alpha: 0.18),
        CGColor(red: 0.5, green: 0.35, blue: 1.0, alpha: 0.0),
    ] as CFArray
    let glowGrad = CGGradient(colorsSpace: space, colors: glowColors, locations: stops)!
    ctx.drawRadialGradient(glowGrad,
        startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
        endCenter:   CGPoint(x: cx, y: cy), endRadius: glowRadius,
        options: [])

    // White waveform + mic symbol, centered
    if let sym = whiteSymbol(named: "waveform.and.mic", pointSize: 500) {
        let s = sym.size
        sym.draw(in: NSRect(x: (iconSize - s.width) / 2,
                            y: (iconSize - s.height) / 2,
                            width: s.width, height: s.height),
                 from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    return true
}

// ── Export all required sizes for the iconset ─────────────────────────────────
let sizes = [1024, 512, 256, 128, 64, 32, 16]

for s in sizes {
    let scaled = NSImage(size: NSSize(width: s, height: s))
    scaled.lockFocus()
    master.draw(in: NSRect(x: 0, y: 0, width: s, height: s),
                from: .zero, operation: .sourceOver, fraction: 1.0)
    scaled.unlockFocus()

    guard let tiff = scaled.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff),
          let png  = rep.representation(using: .png, properties: [:]) else {
        fputs("Failed to render \(s)x\(s)\n", stderr); continue
    }
    let path = "\(outputDir)/icon_\(s)x\(s).png"
    try! png.write(to: URL(fileURLWithPath: path))
    print("  \(s)x\(s) → \(path)")
}
