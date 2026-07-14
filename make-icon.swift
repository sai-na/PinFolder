// Generate PinFolder's app icon + web/social assets from the canonical logo:
//   docs/internal/logo/pinfolder-logo.svg
//
//   swift make-icon.swift          (needs `brew install librsvg` for rsvg-convert)
//
// Writes:
//   AppIcon.icns                    app bundle icon (via iconutil)
//   docs/assets/icon-1024.png       full-size logo
//   docs/assets/icon-256.png        README logo
//   docs/assets/icon-32.png         favicon
//   docs/assets/apple-touch-icon.png (180)
//   docs/assets/og-image.png        1200x630 link-preview card
//
// Every size is rendered straight from the SVG (no downscaling), so edges
// stay crisp. Generated assets are committed; this only needs re-running
// after the logo SVG changes.

import AppKit
import CoreGraphics

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let svg = root.appendingPathComponent("docs/internal/logo/pinfolder-logo.svg")
let assets = root.appendingPathComponent("docs/assets")

func run(_ tool: String, _ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    try! p.run(); p.waitUntilExit()
    guard p.terminationStatus == 0 else { fatalError("\(tool) \(args) failed") }
}

guard let rsvg = ["/opt/homebrew/bin/rsvg-convert", "/usr/local/bin/rsvg-convert"]
    .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
    fatalError("rsvg-convert not found - brew install librsvg")
}

func render(px: Int, to url: URL) {
    run(rsvg, ["-w", String(px), "-h", String(px), svg.path, "-o", url.path])
}

// ---- iconset -> AppIcon.icns ----
let iconsetDir = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetDir)
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    render(px: base, to: iconsetDir.appendingPathComponent("icon_\(base)x\(base).png"))
    render(px: base * 2, to: iconsetDir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
run("/usr/bin/iconutil", ["-c", "icns", iconsetDir.path, "-o", root.appendingPathComponent("AppIcon.icns").path])
print("AppIcon.icns")

// ---- web assets ----
try! FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
for (px, name) in [(1024, "icon-1024.png"), (256, "icon-256.png"), (32, "icon-32.png"), (180, "apple-touch-icon.png")] {
    render(px: px, to: assets.appendingPathComponent(name))
    print("docs/assets/\(name)")
}

// ---- og-image 1200x630: logo left, wordmark right ----
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let W = 1200, H = 630
let c = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
c.setFillColor(rgb(0xFDF6EC))                       // warm paper, matches the site
c.fill(CGRect(x: 0, y: 0, width: W, height: H))
c.setFillColor(rgb(0xE8D9C3, 0.6))                  // faint corkboard dots
for x in stride(from: 40, to: W, by: 56) {
    for y in stride(from: 40, to: H, by: 56) {
        c.fillEllipse(in: CGRect(x: x, y: y, width: 4, height: 4))
    }
}
let logoPng = assets.appendingPathComponent("icon-1024.png")
let logo = NSImage(contentsOf: logoPng)!
var logoRect = CGRect(x: 96, y: (CGFloat(H) - 360) / 2, width: 360, height: 360)
c.draw(logo.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: logoRect)

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
         at: CGPoint(x: 490, y: 350))
drawText("Pin files & folders on macOS", size: 40, weight: .medium,
         color: NSColor(srgbRed: 0.42, green: 0.38, blue: 0.34, alpha: 1), at: CGPoint(x: 492, y: 280))
drawText("Menu bar  ·  top of folder  ·  Finder sidebar", size: 32, weight: .regular,
         color: NSColor(srgbRed: 0.55, green: 0.50, blue: 0.45, alpha: 1), at: CGPoint(x: 492, y: 222))
let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent("og-image.png"))
print("docs/assets/og-image.png")
