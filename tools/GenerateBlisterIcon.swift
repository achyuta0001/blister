// Generates the Blister app icon: `1:64` on a dark #1C1C1C field, colon in the vermilion accent.
// Standalone build tool — kept outside `Blister/` so the Xcode synchronized group never compiles it
// into the app. Run: `swift tools/GenerateBlisterIcon.swift`
// Uses only system frameworks (CoreGraphics, CoreText, ImageIO) — zero third-party dependencies.

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outputPath = "Blister/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

// Palette (matches DesignTokens / AccentColor.colorset).
let background = CGColor(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1C / 255, alpha: 1)
let ink = CGColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1)         // near-white digits
let accent = CGColor(red: 0.910, green: 0.361, blue: 0.251, alpha: 1)   // vermilion colon

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
          data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
          space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
    FileHandle.standardError.write(Data("Failed to create CGContext\n".utf8))
    exit(1)
}

// Background fill.
ctx.setFillColor(background)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Build one attributed string "1:64" so the digits share a baseline and metrics, then colour the
// colon glyph run separately.
let fontSize: CGFloat = 430
let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
let tracking: CGFloat = -12   // tight tracking, per the app's heading style

func makeLine() -> CTLine {
    let full = "1:64"
    let attr = NSMutableAttributedString(string: full)
    let whole = NSRange(location: 0, length: full.utf16.count)
    attr.addAttribute(kCTFontAttributeName as NSAttributedString.Key, value: font, range: whole)
    attr.addAttribute(kCTKernAttributeName as NSAttributedString.Key, value: tracking, range: whole)
    attr.addAttribute(kCTForegroundColorAttributeName as NSAttributedString.Key, value: ink, range: whole)
    // The colon is at index 1.
    let colon = NSRange(location: 1, length: 1)
    attr.addAttribute(kCTForegroundColorAttributeName as NSAttributedString.Key, value: accent, range: colon)
    return CTLineCreateWithAttributedString(attr as CFAttributedString)
}

let line = makeLine()
let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

// Centre the mark optically.
let x = (CGFloat(size) - bounds.width) / 2 - bounds.origin.x
let y = (CGFloat(size) - bounds.height) / 2 - bounds.origin.y

ctx.textPosition = CGPoint(x: x, y: y)
CTLineDraw(line, ctx)

guard let image = ctx.makeImage() else {
    FileHandle.standardError.write(Data("Failed to make image\n".utf8))
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("Failed to create image destination at \(outputPath)\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("Failed to write PNG\n".utf8))
    exit(1)
}

print("Wrote \(outputPath) (\(size)x\(size))")
