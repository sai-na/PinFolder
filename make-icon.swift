// Generate PinFolder's app icon + web/social assets. Pure CoreGraphics,
// so every size renders crisp (no emoji bitmaps, no external tools).
//
//   swift make-icon.swift
//
// Writes:
//   AppIcon.icns                    app bundle icon (via iconutil)
//   docs/assets/icon-1024.png       full-size logo
//   docs/assets/icon-256.png        README logo
//   docs/assets/icon-32.png         favicon
//   docs/assets/apple-touch-icon.png (180)
//   docs/assets/og-image.png        1200x630 link-preview card
//
// Design: macOS squircle, warm red gradient, white pushpin tilted like a
// real tack in a corkboard. Matches the 📌 the product uses everywhere.

import AppKit
import CoreGraphics

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("docs/assets")

func ctx(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// The pushpin glyph, drawn upright in a 0..1 box (x centered at 0.5), then
// tilted. Classic side-view tack: flat cap, neck, flange, needle.
func pinPath(size s: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let cx = 0.5 * s
    let top = 0.80 * s        // glyph occupies vertical band, y-up coords
    let capW = 0.40 * s, capH = 0.115 * s
    let neckTopW = 0.15 * s, neckBotW = 0.105 * s, neckH = 0.13 * s
    let flangeW = 0.30 * s, flangeH = 0.075 * s
    let needleLen = 0.30 * s, needleW = 0.052 * s

    // cap (rounded rect)
    p.addRoundedRect(in: CGRect(x: cx - capW/2, y: top - capH, width: capW, height: capH),
                     cornerWidth: capH * 0.45, cornerHeight: capH * 0.45)
    // neck (trapezoid)
    let neckTop = top - capH
    p.move(to: CGPoint(x: cx - neckTopW/2, y: neckTop))
    p.addLine(to: CGPoint(x: cx + neckTopW/2, y: neckTop))
    p.addLine(to: CGPoint(x: cx + neckBotW/2, y: neckTop - neckH))
    p.addLine(to: CGPoint(x: cx - neckBotW/2, y: neckTop - neckH))
    p.closeSubpath()
    // flange (rounded rect)
    let flangeTop = neckTop - neckH
    p.addRoundedRect(in: CGRect(x: cx - flangeW/2, y: flangeTop - flangeH, width: flangeW, height: flangeH),
                     cornerWidth: flangeH * 0.5, cornerHeight: flangeH * 0.5)
    // needle (triangle)
    let needleTop = flangeTop - flangeH
    p.move(to: CGPoint(x: cx - needleW/2, y: needleTop))
    p.addLine(to: CGPoint(x: cx + needleW/2, y: needleTop))
    p.addLine(to: CGPoint(x: cx, y: needleTop - needleLen))
    p.closeSubpath()
    return p
}

func drawIcon(_ s: CGFloat, into c: CGContext) {
    let inset = 0.098 * s                 // Apple margin: icon art ~80% of canvas
    let rect = CGRect(x: inset, y: inset, width: s - 2*inset, height: s - 2*inset)
    let radius = 0.225 * rect.width
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // soft drop shadow like system icons
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -0.012 * s), blur: 0.045 * s,
                color: rgb(0x000000, 0.30))
    c.addPath(squircle)
    c.setFillColor(rgb(0xE0352B))
    c.fillPath()
    c.restoreGState()

    // red gradient fill
    c.saveGState()
    c.addPath(squircle)
    c.clip()
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [rgb(0xFF7A5C), rgb(0xF04E3E), rgb(0xC9251C)] as CFArray,
                          locations: [0, 0.55, 1])!
    c.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.maxY),
                         end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    // subtle top sheen
    let sheen = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0.0)] as CFArray,
                           locations: [0, 1])!
    c.drawLinearGradient(sheen, start: CGPoint(x: rect.midX, y: rect.maxY),
                         end: CGPoint(x: rect.midX, y: rect.midY), options: [])
    // white pushpin, tilted ~35° like a tack pressed into a board
    c.translateBy(x: 0.54 * s, y: 0.545 * s)
    c.rotate(by: -35 * .pi / 180)
    c.translateBy(x: -0.5 * s, y: -0.5 * s)
    c.setShadow(offset: CGSize(width: 0, height: -0.015 * s), blur: 0.03 * s,
                color: rgb(0x7A0F08, 0.55))
    c.addPath(pinPath(size: s))
    c.setFillColor(rgb(0xFFFFFF))
    c.fillPath()
    c.restoreGState()
}

func pngData(_ c: CGContext) -> Data {
    let img = c.makeImage()!
    let rep = NSBitmapImageRep(cgImage: img)
    return rep.representation(using: .png, properties: [:])!
}

func writeIcon(px: Int, to url: URL) {
    let c = ctx(px, px)
    drawIcon(CGFloat(px), into: c)
    try! pngData(c).write(to: url)
}

// ---- iconset -> AppIcon.icns ----
let iconsetDir = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetDir)
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    writeIcon(px: base, to: iconsetDir.appendingPathComponent("icon_\(base)x\(base).png"))
    writeIcon(px: base * 2, to: iconsetDir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", root.appendingPathComponent("AppIcon.icns").path]
try! iconutil.run(); iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("AppIcon.icns")

// ---- web assets ----
try! FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
for (px, name) in [(1024, "icon-1024.png"), (256, "icon-256.png"), (32, "icon-32.png"), (180, "apple-touch-icon.png")] {
    writeIcon(px: px, to: assets.appendingPathComponent(name))
    print("docs/assets/\(name)")
}

// ---- og-image 1200x630 ----
let W = 1200, H = 630
let c = ctx(W, H)
c.setFillColor(rgb(0xFDF6EC))                       // warm paper
c.fill(CGRect(x: 0, y: 0, width: W, height: H))
// faint corkboard dots
c.setFillColor(rgb(0xE8D9C3, 0.6))
for x in stride(from: 40, to: W, by: 56) {
    for y in stride(from: 40, to: H, by: 56) {
        c.fillEllipse(in: CGRect(x: x, y: y, width: 4, height: 4))
    }
}
// icon on the left
c.saveGState()
c.translateBy(x: 90, y: CGFloat(H)/2 - 160)
drawIcon(320, into: c)
c.restoreGState()

func drawText(_ str: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, at pt: CGPoint) {
    let attr = NSAttributedString(string: str, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
    ])
    let line = CTLineCreateWithAttributedString(attr)
    c.textPosition = pt
    CTLineDraw(line, c)
}
NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
drawText("PinFolder", size: 92, weight: .bold, color: NSColor(srgbRed: 0.13, green: 0.12, blue: 0.11, alpha: 1),
         at: CGPoint(x: 460, y: 350))
drawText("Pin files & folders on macOS", size: 40, weight: .medium,
         color: NSColor(srgbRed: 0.42, green: 0.38, blue: 0.34, alpha: 1), at: CGPoint(x: 462, y: 280))
drawText("Menu bar  ·  top of folder  ·  Finder sidebar", size: 32, weight: .regular,
         color: NSColor(srgbRed: 0.55, green: 0.50, blue: 0.45, alpha: 1), at: CGPoint(x: 462, y: 222))
try! pngData(c).write(to: assets.appendingPathComponent("og-image.png"))
print("docs/assets/og-image.png")
