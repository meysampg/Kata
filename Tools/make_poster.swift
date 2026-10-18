#!/usr/bin/env swift
// Renders the Kata README poster (docs/poster.png + docs/poster.jpg), 2400x1600.
// Deterministic: CoreGraphics + CoreText + ImageIO only, no network.
// Run from the repository root:  swift Tools/make_poster.swift
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let W: CGFloat = 2400, Hh: CGFloat = 1600
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func Y(_ y: CGFloat) -> CGFloat { Hh - y }
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, a])!
}
func grad(_ stops: [(UInt32, CGFloat, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: stops.map { color($0.0, $0.1) } as CFArray, locations: stops.map { $0.2 })!
}

// Palette (accent = AccentColor.colorset #0F6E78)
let bg: UInt32 = 0x0B1215, accent: UInt32 = 0x0F6E78, glowTeal: UInt32 = 0x2BB8C6
let fg: UInt32 = 0xE6EDF0, dim: UInt32 = 0x7C969B, comment: UInt32 = 0x5F8A8F
let kw: UInt32 = 0xFF7AB6, typ: UInt32 = 0x56D4DD, str: UInt32 = 0xE6C07B, num: UInt32 = 0xB48EF5
let bezel: UInt32 = 0x07090B

// Fonts: SF Mono if CoreText resolves it, else Menlo, else Courier.
func mono(_ size: CGFloat, bold: Bool = false) -> CTFont {
    let names = bold ? ["SFMono-Bold", "Menlo-Bold", "Courier-Bold"] : ["SFMono-Medium", "SFMono-Regular", "Menlo-Regular", "Courier"]
    for n in names {
        let f = CTFontCreateWithName(n as CFString, size, nil)
        if (CTFontCopyPostScriptName(f) as String) == n { return f }
    }
    return CTFontCreateWithName("Menlo" as CFString, size, nil)
}

let ctx = CGContext(data: nil, width: Int(W), height: Int(Hh), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setLineJoin(.round); ctx.setLineCap(.round)
ctx.setAllowsFontSmoothing(false)

func fillPath(_ p: CGPath, _ c: CGColor) { ctx.addPath(p); ctx.setFillColor(c); ctx.fillPath() }
func strokePath(_ p: CGPath, _ c: CGColor, _ w: CGFloat) { ctx.addPath(p); ctx.setStrokeColor(c); ctx.setLineWidth(w); ctx.strokePath() }
func rrect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x0, y: Y(y1), width: x1 - x0, height: y1 - y0), cornerWidth: r, cornerHeight: r, transform: nil)
}
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - r, y: Y(cy) - r, width: 2 * r, height: 2 * r), transform: nil)
}
func line(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ c: CGColor, _ w: CGFloat) {
    let p = CGMutablePath(); p.move(to: CGPoint(x: x0, y: Y(y0))); p.addLine(to: CGPoint(x: x1, y: Y(y1))); strokePath(p, c, w)
}

typealias Run = (String, UInt32)
func runsWidth(_ runs: [Run], _ font: CTFont) -> CGFloat {
    runs.reduce(0) { acc, r in
        acc + CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(NSAttributedString(string: r.0, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])), nil, nil, nil))
    }
}
/// Draws coloured runs; align 0 = left at x, 0.5 = centred on x, 1 = right-aligned.
func text(_ runs: [Run], _ font: CTFont, x: CGFloat, base: CGFloat, align: CGFloat = 0, alpha: CGFloat = 1) {
    var cx = x - runsWidth(runs, font) * align
    for r in runs {
        let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(r.1, alpha)]
        let l = CTLineCreateWithAttributedString(NSAttributedString(string: r.0, attributes: attrs))
        ctx.textPosition = CGPoint(x: cx, y: Y(base)); CTLineDraw(l, ctx)
        cx += CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil))
    }
}
func loadImage(_ path: String) -> CGImage {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let im = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        FileHandle.standardError.write(Data("cannot load \(path)\n".utf8)); exit(1)
    }
    return im
}

// ------------------------------------------------------------ Background
ctx.setFillColor(color(bg)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: Hh))
ctx.drawRadialGradient(grad([(0x123238, 0.9, 0), (bg, 0, 1)]), startCenter: CGPoint(x: 1200, y: Y(900)), startRadius: 0,
                       endCenter: CGPoint(x: 1200, y: Y(900)), endRadius: 1300, options: [])
ctx.drawRadialGradient(grad([(glowTeal, 0.10, 0), (glowTeal, 0, 1)]), startCenter: CGPoint(x: 300, y: Y(150)), startRadius: 0,
                       endCenter: CGPoint(x: 300, y: Y(150)), endRadius: 700, options: [])
// dot grid
for j in 0...40 { for i in 0...60 {
    let on = (i % 5 == 0 && j % 5 == 0)
    fillPath(circle(CGFloat(i) * 40, CGFloat(j) * 40, on ? 2.2 : 1.3), color(0x9FD8DE, on ? 0.13 : 0.07))
} }
// faint background code (Strategy sample)
do {
    let f = mono(34)
    let code: [[Run]] = [
        [("interface ", kw), ("PricingStrategy ", typ), ("{", fg)],
        [("    BigDecimal ", typ), ("price", fg), ("(", fg), ("BigDecimal ", typ), ("base", fg), (");", fg)],
        [("}", fg)], [("", fg)],
        [("record ", kw), ("Seasonal", typ), ("(", fg), ("int ", kw), ("pct", fg), (") ", fg), ("implements ", kw), ("PricingStrategy ", typ), ("{", fg)],
        [("    public ", kw), ("BigDecimal ", typ), ("price", fg), ("(", fg), ("BigDecimal ", typ), ("base", fg), (") {", fg)],
        [("        return ", kw), ("base.multiply(", fg), ("factor", fg), (");", fg)],
        [("    }", fg)], [("}", fg)], [("", fg)],
        [("var ", kw), ("cart ", fg), ("= ", fg), ("new ", kw), ("Checkout", typ), ("(", fg), ("new ", kw), ("Seasonal", typ), ("(", fg), ("20", num), ("));", fg)],
    ]
    for (i, l) in code.enumerated() { text(l, f, x: 90, base: 500 + CGFloat(i) * 46, alpha: 0.055) }
}

// ------------------------------------------------------------ Title block
let iconX: CGFloat = 110, iconY: CGFloat = 96, iconS: CGFloat = 168
do {
    let r = iconS * 0.225
    let p = rrect(iconX, iconY, iconX + iconS, iconY + iconS, r)
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 50, color: color(glowTeal, 0.45))
    fillPath(p, color(accent)); ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(p); ctx.clip()
    ctx.draw(loadImage("Kata/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"),
             in: CGRect(x: iconX, y: Y(iconY + iconS), width: iconS, height: iconS))
    ctx.restoreGState()
    strokePath(rrect(iconX + 0.5, iconY + 0.5, iconX + iconS - 0.5, iconY + iconS - 0.5, r), color(0xFFFFFF, 0.18), 1.5)
    let tf = mono(150, bold: true)
    text([("Kata", fg)], tf, x: iconX + iconS + 40, base: iconY + 128)
    let tw = runsWidth([("Kata", fg)], tf)
    // cursor block
    let cx = iconX + iconS + 40 + tw + 18
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 24, color: color(glowTeal, 0.8))
    fillPath(rrect(cx, iconY + 28, cx + 54, iconY + 136, 6), color(glowTeal)); ctx.restoreGState()
    text([("// ", comment), ("master design patterns through deliberate practice", comment)], mono(35), x: iconX, base: 342)
    // chips
    let cf = mono(24)
    let chips = ["70 patterns", "Java 21", "350 exercises", "FSRS", "UML diagrams", "offline", "iOS 26"]
    var x = iconX
    for (i, c) in chips.enumerated() {
        let runs: [Run] = [("$ ", glowTeal), (c, fg)]
        let w = runsWidth(runs, cf) + 40
        let p = rrect(x, 390, x + w, 446, 12)
        fillPath(p, color(i == 0 ? accent : 0x14232A, i == 0 ? 0.9 : 1))
        strokePath(rrect(x + 0.75, 390.75, x + w - 0.75, 445.25, 11.5), color(glowTeal, i == 0 ? 0.9 : 0.35), 1.5)
        text(runs, cf, x: x + 20, base: 426)
        x += w + 14
    }
}
// terminal card (top right)
do {
    let x0: CGFloat = 1640, y0: CGFloat = 96, x1: CGFloat = 2290, y1: CGFloat = 446
    let card = rrect(x0, y0, x1, y1, 22)
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 40, color: color(0x000000, 0.55))
    fillPath(card, color(0x0F1A1F)); ctx.restoreGState()
    strokePath(rrect(x0 + 0.75, y0 + 0.75, x1 - 0.75, y1 - 0.75, 21.5), color(0xFFFFFF, 0.12), 1.5)
    for (i, c) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() { fillPath(circle(x0 + 36 + CGFloat(i) * 28, y0 + 34, 8), color(UInt32(c), 0.9)) }
    line(x0, y0 + 66, x1, y0 + 66, color(0xFFFFFF, 0.08), 1.5)
    text([("kata \u{2014} today", dim)], mono(20), x: x1 - 28, base: y0 + 40, align: 1)
    let f = mono(25)
    let rows: [[Run]] = [
        [("$ ", glowTeal), ("kata review --due", fg)],
        [("  strategy   ", typ), ("Good   ", str), ("\u{2192} 9d", dim)],
        [("  observer   ", typ), ("Again  ", kw), ("\u{2192} 1d", dim)],
        [("  decorator  ", typ), ("Easy   ", num), ("\u{2192} 21d", dim)],
        [("  retention  ", dim), ("90%  ", str), ("\u{25AE}\u{25AE}\u{25AE}\u{25AE}\u{25AE}\u{25AE}\u{25AE}\u{25AE}\u{25AE}\u{25AF}", glowTeal)],
        [("$ ", glowTeal), ("\u{2588}", glowTeal)],
    ]
    for (i, r) in rows.enumerated() { text(r, f, x: x0 + 32, base: y0 + 112 + CGFloat(i) * 44) }
}

// ------------------------------------------------------------ Phones
struct Slot { let file, name: String; let note: String; let S: CGFloat }
let slots: [Slot] = [
    Slot(file: "01-today", name: "today()", note: "// next review", S: 640),
    Slot(file: "02-path", name: "path()", note: "// guided path", S: 700),
    Slot(file: "04-deck-definition", name: "definition()", note: "// one card, one idea", S: 780),
    Slot(file: "05-deck-implementation", name: "implementation()", note: "// code walkthrough", S: 780),
    Slot(file: "07-deck-structure", name: "structure()", note: "// native UML", S: 700),
    Slot(file: "11-practice", name: "practice()", note: "// spaced repetition", S: 640),
]
func dims(_ S: CGFloat) -> (sw: CGFloat, b: CGFloat, dw: CGFloat, dh: CGFloat) {
    let sw = 0.462 * S, b = 0.018 * S
    return (sw, b, sw + 2 * b, S + 2 * b)
}
let gap: CGFloat = 22
let total = slots.reduce(0) { $0 + dims($1.S).dw } + gap * CGFloat(slots.count - 1)
var px = (W - total) / 2
let bottom: CGFloat = 1296
func phone(_ s: Slot, left: CGFloat) {
    let (sw, b, dw, dh) = dims(s.S)
    let rS = 0.125 * sw, rD = rS + b
    let top = bottom - dh
    let dev = rrect(left, top, left + dw, bottom, rD)
    // glow + drop shadow
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 90, color: color(glowTeal, 0.28)); fillPath(dev, color(bezel)); ctx.restoreGState()
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 60, color: color(0x000000, 0.6)); fillPath(dev, color(bezel)); ctx.restoreGState()
    fillPath(dev, color(bezel))
    // edge highlight (gradient stroke, bright top-left)
    ctx.saveGState()
    ctx.addPath(dev.copy(strokingWithWidth: 3, lineCap: .butt, lineJoin: .round, miterLimit: 4)); ctx.clip()
    ctx.drawLinearGradient(grad([(0xBFD6DA, 0.75, 0), (0x4A6A70, 0.45, 0.45), (0x2A4045, 0.55, 1)]),
                           start: CGPoint(x: left, y: Y(top)), end: CGPoint(x: left + dw, y: Y(bottom)), options: [])
    ctx.restoreGState()
    strokePath(rrect(left + 3.5, top + 3.5, left + dw - 3.5, bottom - 3.5, rD - 3.5), color(0x000000, 0.9), 1.5)
    // screen
    let sx = left + b, sy = top + b
    let scr = rrect(sx, sy, sx + sw, sy + s.S, rS)
    ctx.saveGState(); ctx.addPath(scr); ctx.clip()
    ctx.setFillColor(color(0x000000)); ctx.fill(CGRect(x: sx, y: Y(sy + s.S), width: sw, height: s.S))
    ctx.interpolationQuality = .high
    ctx.draw(loadImage("docs/screenshots/\(s.file).png"), in: CGRect(x: sx, y: Y(sy + s.S), width: sw, height: s.S))
    ctx.drawLinearGradient(grad([(0xFFFFFF, 0.07, 0), (0xFFFFFF, 0, 1)]),
                           start: CGPoint(x: sx, y: Y(sy)), end: CGPoint(x: sx + 0.5 * sw, y: Y(sy + 0.35 * s.S)), options: [])
    ctx.restoreGState()
    // annotation
    let cx = left + dw / 2
    line(cx, bottom + 14, cx, bottom + 64, color(glowTeal, 0.55), 1.5)
    fillPath(circle(cx, bottom + 14, 4.5), color(glowTeal))
    fillPath(circle(cx, bottom + 64, 3), color(glowTeal, 0.55))
    text([(s.name, fg)], mono(27, bold: true), x: cx, base: bottom + 104, align: 0.5)
    text([(s.note, comment)], mono(22), x: cx, base: bottom + 138, align: 0.5)
}
for s in slots { phone(s, left: px); px += dims(s.S).dw + gap }

// ------------------------------------------------------------ Category legend
do {
    let f = mono(24)
    let cats = ["Foundations", "Creational", "Structural", "Behavioral", "Concurrency", "Enterprise", "Resilience"]
    var runs: [Run] = [("final var ", kw), ("categories ", fg), ("= ", fg), ("List", typ), (".of(", fg)]
    for (i, c) in cats.enumerated() { runs.append(("\"\(c)\"", str)); if i < cats.count - 1 { runs.append((", ", fg)) } }
    runs.append((");", fg))
    let w = runsWidth(runs, f)
    let x0 = (W - w) / 2
    line(110, 1486, W - 110, 1486, color(0xFFFFFF, 0.07), 1.5)
    text(runs, f, x: x0, base: 1538)
}

// Vignette
ctx.drawRadialGradient(grad([(0x000000, 0, 0), (0x000000, 0, 0.62), (0x000000, 0.4, 1)]),
                       startCenter: CGPoint(x: 1200, y: Y(800)), startRadius: 0, endCenter: CGPoint(x: 1200, y: Y(800)),
                       endRadius: 1500, options: [.drawsAfterEndLocation])

// ------------------------------------------------------------ Output
let image = ctx.makeImage()!
func write(_ path: String, _ type: UTType, _ opts: [CFString: Any]?, _ im: CGImage) {
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, im, opts as CFDictionary?)
    guard CGImageDestinationFinalize(d) else { FileHandle.standardError.write(Data("failed \(path)\n".utf8)); exit(1) }
}
write("docs/poster.png", .png, nil, image)
let flat = CGContext(data: nil, width: Int(W), height: Int(Hh), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                     bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
flat.draw(image, in: CGRect(x: 0, y: 0, width: W, height: Hh))
write("docs/poster.jpg", .jpeg, [kCGImageDestinationLossyCompressionQuality: 0.9], flat.makeImage()!)
print("done")
