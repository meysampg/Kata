#!/usr/bin/env swift
// Renders the Kata app icon into the iOS AppIcon asset set (three opaque 1024x1024 PNGs) and into the
// macOS AppIcon asset set of KataMac (the same art inside a rounded rectangle with a soft shadow, 16...1024 px).
// An ensō (brush circle, drawn as a variable-width filled path) around a small UML-style pattern motif.
// Run from the repository root:  swift Tools/make_app_icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outDir = "Kata/Resources/Assets.xcassets/AppIcon.appiconset"
let macOutDir = "KataMac/Resources/Assets.xcassets/AppIcon.appiconset"

struct Variant {
    let file: String
    let top: UInt32
    let bottom: UInt32
    let enso: UInt32
    let node: UInt32
    let accent: UInt32
    let glow: UInt32?
}

let variants = [
    Variant(file: "AppIcon.png", top: 0x14838F, bottom: 0x083F47, enso: 0xFBF6EA, node: 0xFBF6EA, accent: 0x7FE0E6, glow: 0x3FB4BF),
    Variant(file: "AppIcon-Dark.png", top: 0x10292D, bottom: 0x050E10, enso: 0x3FB4BF, node: 0xBFEFF1, accent: 0x4FC3C9, glow: 0x1E5A60),
    Variant(file: "AppIcon-Tinted.png", top: 0x000000, bottom: 0x000000, enso: 0xFFFFFF, node: 0xFFFFFF, accent: 0xB0B0B0, glow: nil),
]

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha,
    ])!
}

// MARK: - Ensō path

/// Closed filled path: outer edge out along the stroke, inner edge back. Radius and thickness vary along
/// the stroke (thick start with a slight inward spiral, tapering to a dry-brush tail) plus small wobble.
func ensoPath(center: CGPoint) -> CGPath {
    let startDeg = 58.0, sweepDeg = 330.0   // starts upper right, runs counter-clockwise, gap ends up at ~ 20 degrees
    let steps = 360
    var outer: [CGPoint] = [], inner: [CGPoint] = []
    for i in 0...steps {
        let u = Double(i) / Double(steps)
        let a = (startDeg + sweepDeg * u) * .pi / 180
        // Thickness: swells quickly at the start, holds, then tapers to a thin tail.
        let swell = min(1, u / 0.06)
        let body = 1 - pow(max(0, (u - 0.3) / 0.7), 1.5) * 0.82
        let thick = 96 * (0.55 + 0.45 * swell.squareRoot()) * body
        let wobble = 2.2 * sin(u * 9 + 0.5) + 1.2 * sin(u * 31 + 1.3) + 0.5 * sin(u * 83 + 0.4)
        let r = 276 - 22 * u * u + 6 * sin(u * 5.5 + 0.8)   // slight inward spiral
        let rOut = r + thick / 2 + wobble * 0.8
        let rIn = r - thick / 2 - wobble * 0.5
        outer.append(CGPoint(x: center.x + rOut * cos(a), y: center.y + rOut * sin(a)))
        inner.append(CGPoint(x: center.x + rIn * cos(a), y: center.y + rIn * sin(a)))
    }
    let p = CGMutablePath()
    p.move(to: outer[0])
    for pt in outer.dropFirst() { p.addLine(to: pt) }
    for pt in inner.reversed() { p.addLine(to: pt) }
    p.closeSubpath()
    return p
}

// MARK: - Render

func roundedRect(_ c: CGPoint, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
}

/// Draws the full-bleed 1024x1024 artwork of a variant.
func artwork(_ v: Variant) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let mid = CGPoint(x: 512, y: 512)
    let ensoCenter = CGPoint(x: 526, y: 512)

    let gradient = CGGradient(colorsSpace: space, colors: [color(v.top), color(v.bottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

    if let glow = v.glow {
        let g = CGGradient(colorsSpace: space, colors: [color(glow, alpha: 0.5), color(glow, alpha: 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: mid, startRadius: 0, endCenter: mid, endRadius: 560, options: [])
    }

    // Ensō.
    ctx.saveGState()
    if v.glow != nil { ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: color(0x000000, alpha: 0.3)) }
    ctx.setFillColor(color(v.enso))
    ctx.addPath(ensoPath(center: ensoCenter))
    ctx.fillPath()
    ctx.restoreGState()

    // Pattern motif: interface on top, two implementations below (Strategy shape).
    let top = CGPoint(x: 521, y: 606), left = CGPoint(x: 424, y: 424), right = CGPoint(x: 618, y: 424)
    let topSize = CGSize(width: 184, height: 104), botSize = CGSize(width: 136, height: 88)
    let lineW: CGFloat = 11

    ctx.saveGState()
    if v.glow != nil { ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x000000, alpha: 0.28)) }
    ctx.setStrokeColor(color(v.node))
    ctx.setLineWidth(lineW)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    // Elbow connectors: down from the top node, across, down into each child.
    let busY = (top.y - topSize.height / 2 + left.y + botSize.height / 2) / 2
    let connectors = CGMutablePath()
    connectors.move(to: CGPoint(x: top.x, y: top.y - topSize.height / 2))
    connectors.addLine(to: CGPoint(x: top.x, y: busY))
    connectors.move(to: CGPoint(x: left.x, y: busY)); connectors.addLine(to: CGPoint(x: right.x, y: busY))
    for c in [left, right] {
        connectors.move(to: CGPoint(x: c.x, y: busY))
        connectors.addLine(to: CGPoint(x: c.x, y: c.y + botSize.height / 2))
    }
    ctx.addPath(connectors)
    ctx.strokePath()

    // Top node: outlined (the interface); bottom nodes: filled (implementations).
    let topRect = roundedRect(top, topSize.width, topSize.height)
    ctx.setFillColor(color(v.top == v.bottom ? 0x000000 : v.bottom, alpha: 1))
    ctx.addPath(CGPath(roundedRect: topRect, cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()
    ctx.setStrokeColor(color(v.node))
    ctx.setLineWidth(lineW)
    ctx.addPath(CGPath(roundedRect: topRect.insetBy(dx: lineW / 2, dy: lineW / 2), cornerWidth: 22, cornerHeight: 22, transform: nil))
    ctx.strokePath()
    ctx.setFillColor(color(v.node))
    for c in [left, right] {
        ctx.addPath(CGPath(roundedRect: roundedRect(c, botSize.width, botSize.height), cornerWidth: 24, cornerHeight: 24, transform: nil))
        ctx.fillPath()
    }
    ctx.restoreGState()

    // Accent: a small bar inside the top node and a dot in each child.
    ctx.setFillColor(color(v.accent))
    ctx.addPath(CGPath(roundedRect: roundedRect(top, 70, 16), cornerWidth: 8, cornerHeight: 8, transform: nil))
    ctx.fillPath()
    ctx.setFillColor(color(v.top == v.bottom ? 0x808080 : v.bottom))
    for c in [left, right] {
        ctx.addPath(CGPath(roundedRect: roundedRect(c, 56, 16), cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.fillPath()
    }

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        FileHandle.standardError.write(Data("failed to write \(url.path)\n".utf8))
        exit(1)
    }
    print("wrote \(url.path)")
}

func render(_ v: Variant) {
    write(artwork(v), to: URL(fileURLWithPath: outDir).appendingPathComponent(v.file))
}

// MARK: - macOS icon

/// macOS icon master: the artwork clipped to a rounded rectangle (824 pt body on a 1024 canvas, corner
/// radius about 22.5%) with a soft drop shadow, on a transparent background.
func macMaster(_ art: CGImage) -> CGImage {
    let rgba = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                         space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    rgba.saveGState()
    rgba.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, alpha: 0.35))
    rgba.setFillColor(color(0x083F47))
    rgba.addPath(shape)
    rgba.fillPath()
    rgba.restoreGState()
    rgba.saveGState()
    rgba.addPath(shape)
    rgba.clip()
    rgba.interpolationQuality = .high
    rgba.draw(art, in: body)
    rgba.restoreGState()
    // A hairline highlight along the top edge keeps the shape readable on dark backgrounds.
    rgba.saveGState()
    rgba.addPath(shape)
    rgba.setStrokeColor(color(0xFFFFFF, alpha: 0.12))
    rgba.setLineWidth(2)
    rgba.strokePath()
    rgba.restoreGState()
    return rgba.makeImage()!
}

func scaled(_ image: CGImage, to px: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: px, height: px))
    return ctx.makeImage()!
}

func renderMac() {
    let master = macMaster(artwork(variants[0]))
    let dir = URL(fileURLWithPath: macOutDir)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var images: [[String: String]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let px = points * scale
            let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
            write(px == 1024 ? master : scaled(master, to: px), to: dir.appendingPathComponent(name))
            images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
        }
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let data = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: dir.appendingPathComponent("Contents.json"))
}

variants.forEach(render)
renderMac()
