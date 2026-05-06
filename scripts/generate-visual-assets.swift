#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let assetCatalog = root
    .appendingPathComponent("app/Sunclub/Resources/Assets.xcassets", isDirectory: true)

private struct RGBA {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat

    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    var cgColor: CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }
}

private enum Palette {
    static let cream = RGBA(0.982, 0.965, 0.939)
    static let pearl = RGBA(1.000, 0.988, 0.960)
    static let warmGlow = RGBA(1.000, 0.930, 0.760)
    static let sun = RGBA(0.980, 0.643, 0.012)
    static let coral = RGBA(0.960, 0.365, 0.255)
    static let aloe = RGBA(0.365, 0.720, 0.510)
    static let pool = RGBA(0.260, 0.655, 0.850)
    static let magenta = RGBA(0.780, 0.255, 0.560)
    static let ink = RGBA(0.129, 0.114, 0.102)
    static let softInk = RGBA(0.514, 0.459, 0.427)
    static let night = RGBA(0.114, 0.098, 0.086)
    static let nightAmber = RGBA(0.315, 0.164, 0.068)
    static let white = RGBA(1, 1, 1)
}

private struct AssetSpec {
    let name: String
    let width: Int
    let height: Int
    let isOpaque: Bool
    let draw: (CGContext, CGSize) -> Void
}

private let assetScales = [1, 2, 3]

private func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

private func fill(_ context: CGContext, _ color: RGBA, in rect: CGRect) {
    context.setFillColor(color.cgColor)
    context.fill(rect)
}

private func fillPath(_ context: CGContext, _ color: RGBA, path: CGPath) {
    context.setFillColor(color.cgColor)
    context.addPath(path)
    context.fillPath()
}

private func stroke(_ context: CGContext, _ color: RGBA, path: CGPath, width: CGFloat) {
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(width)
    context.addPath(path)
    context.strokePath()
}

private func gradient(
    _ context: CGContext,
    colors: [RGBA],
    start: CGPoint,
    end: CGPoint
) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: colors.map(\.cgColor) as CFArray,
        locations: nil
    ) else {
        return
    }
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
}

private func radial(
    _ context: CGContext,
    colors: [RGBA],
    center: CGPoint,
    startRadius: CGFloat = 0,
    endRadius: CGFloat
) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: colors.map(\.cgColor) as CFArray,
        locations: nil
    ) else {
        return
    }
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: startRadius,
        endCenter: center,
        endRadius: endRadius,
        options: [.drawsAfterEndLocation]
    )
}

private func drawGrain(_ context: CGContext, size: CGSize, seed: UInt64, alpha: CGFloat) {
    var state = seed
    let count = Int(size.width * size.height / 850)
    for _ in 0..<count {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let x = CGFloat(state % UInt64(max(Int(size.width), 1)))
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let y = CGFloat(state % UInt64(max(Int(size.height), 1)))
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let brightness = CGFloat(state % 100) / 100
        let dotAlpha = alpha * (0.35 + brightness * 0.65)
        context.setFillColor(CGColor(gray: brightness > 0.5 ? 1 : 0, alpha: dotAlpha))
        context.fill(CGRect(x: x, y: y, width: 1, height: 1))
    }
}

private func drawLightLeakBackground(_ context: CGContext, size: CGSize, dark: Bool) {
    if dark {
        gradient(
            context,
            colors: [RGBA(0.120, 0.104, 0.094), RGBA(0.172, 0.132, 0.098), RGBA(0.095, 0.086, 0.080)],
            start: .zero,
            end: CGPoint(x: size.width, y: size.height)
        )
        for index in 0..<7 {
            let offset = CGFloat(index) * size.height / 6
            strokeLine(
                context,
                RGBA(1, 0.80, 0.45, 0.035),
                from: CGPoint(x: -size.width * 0.10, y: offset),
                to: CGPoint(x: size.width * 1.10, y: offset + size.height * 0.24),
                width: 1.5
            )
        }
        drawGrain(context, size: size, seed: 44, alpha: 0.045)
    } else {
        gradient(
            context,
            colors: [Palette.cream, Palette.pearl, RGBA(1, 0.956, 0.884)],
            start: .zero,
            end: CGPoint(x: size.width, y: size.height)
        )
        for index in 0..<5 {
            let inset = CGFloat(index) * 72
            let rect = CGRect(
                x: -size.width * 0.44 + inset,
                y: -size.width * 0.52 + inset,
                width: size.width * 1.10,
                height: size.width * 1.10
            )
            stroke(
                context,
                RGBA(Palette.sun.r, Palette.sun.g, Palette.sun.b, 0.075 - CGFloat(index) * 0.010),
                path: CGPath(ellipseIn: rect, transform: nil),
                width: 2
            )
        }
        drawGrain(context, size: size, seed: 19, alpha: 0.04)
    }
}

private func drawBottle(_ context: CGContext, center: CGPoint, scale: CGFloat, labelColor: RGBA = Palette.sun) {
    let body = CGRect(x: center.x - 70 * scale, y: center.y - 120 * scale, width: 140 * scale, height: 240 * scale)
    let cap = CGRect(x: center.x - 42 * scale, y: body.minY - 34 * scale, width: 84 * scale, height: 42 * scale)
    let label = body.insetBy(dx: 18 * scale, dy: 58 * scale)

    context.saveGState()
    context.addPath(roundedRect(body, radius: 34 * scale))
    context.clip()
    gradient(context, colors: [Palette.white, RGBA(1, 0.918, 0.685)], start: body.origin, end: CGPoint(x: body.maxX, y: body.maxY))
    context.restoreGState()
    stroke(context, RGBA(0.88, 0.57, 0.18, 0.35), path: roundedRect(body, radius: 34 * scale), width: 3 * scale)

    fill(context, labelColor, in: label)
    context.setFillColor(RGBA(1, 1, 1, 0.38).cgColor)
    context.fillEllipse(in: label.insetBy(dx: 22 * scale, dy: 26 * scale))

    context.addPath(roundedRect(cap, radius: 18 * scale))
    context.clip()
    gradient(context, colors: [Palette.ink, Palette.nightAmber], start: cap.origin, end: CGPoint(x: cap.maxX, y: cap.maxY))
    context.resetClip()
}

private func drawPhone(_ context: CGContext, rect: CGRect, accent: RGBA = Palette.pool) {
    fillPath(context, Palette.ink, path: roundedRect(rect, radius: rect.width * 0.16))
    fillPath(context, Palette.pearl, path: roundedRect(rect.insetBy(dx: 9, dy: 11), radius: rect.width * 0.12))
    let notification = CGRect(x: rect.minX + 24, y: rect.minY + 64, width: rect.width - 48, height: 72)
    context.addPath(roundedRect(notification, radius: 18))
    context.clip()
    gradient(context, colors: [RGBA(1, 1, 1, 0.96), RGBA(1, 0.93, 0.76, 0.96)], start: notification.origin, end: CGPoint(x: notification.maxX, y: notification.maxY))
    context.resetClip()
    context.setFillColor(accent.cgColor)
    context.fillEllipse(in: CGRect(x: notification.minX + 16, y: notification.minY + 22, width: 28, height: 28))
    fill(context, RGBA(0.13, 0.11, 0.10, 0.18), in: CGRect(x: notification.minX + 56, y: notification.minY + 22, width: notification.width - 78, height: 8))
    fill(context, RGBA(0.13, 0.11, 0.10, 0.10), in: CGRect(x: notification.minX + 56, y: notification.minY + 38, width: notification.width - 112, height: 8))
}

private func drawTiltedPhone(
    _ context: CGContext,
    center: CGPoint,
    size: CGSize,
    rotation: CGFloat,
    accent: RGBA
) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: rotation)
    drawPhone(
        context,
        rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
        accent: accent
    )
    context.restoreGState()
}

private func shieldPath(center: CGPoint, scale: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x, y: center.y - 105 * scale))
    path.addCurve(to: CGPoint(x: center.x + 92 * scale, y: center.y - 58 * scale), control1: CGPoint(x: center.x + 34 * scale, y: center.y - 98 * scale), control2: CGPoint(x: center.x + 66 * scale, y: center.y - 82 * scale))
    path.addCurve(to: CGPoint(x: center.x + 58 * scale, y: center.y + 82 * scale), control1: CGPoint(x: center.x + 92 * scale, y: center.y + 26 * scale), control2: CGPoint(x: center.x + 78 * scale, y: center.y + 62 * scale))
    path.addCurve(to: CGPoint(x: center.x, y: center.y + 116 * scale), control1: CGPoint(x: center.x + 34 * scale, y: center.y + 102 * scale), control2: CGPoint(x: center.x + 14 * scale, y: center.y + 112 * scale))
    path.addCurve(to: CGPoint(x: center.x - 58 * scale, y: center.y + 82 * scale), control1: CGPoint(x: center.x - 14 * scale, y: center.y + 112 * scale), control2: CGPoint(x: center.x - 34 * scale, y: center.y + 102 * scale))
    path.addCurve(to: CGPoint(x: center.x - 92 * scale, y: center.y - 58 * scale), control1: CGPoint(x: center.x - 78 * scale, y: center.y + 62 * scale), control2: CGPoint(x: center.x - 92 * scale, y: center.y + 26 * scale))
    path.addCurve(to: CGPoint(x: center.x, y: center.y - 105 * scale), control1: CGPoint(x: center.x - 66 * scale, y: center.y - 82 * scale), control2: CGPoint(x: center.x - 34 * scale, y: center.y - 98 * scale))
    path.closeSubpath()
    return path
}

private func drawShield(_ context: CGContext, center: CGPoint, scale: CGFloat, tint: RGBA = Palette.aloe) {
    let path = shieldPath(center: center, scale: scale)

    context.saveGState()
    context.addPath(path)
    context.clip()
    gradient(context, colors: [tint, RGBA(1, 0.93, 0.76)], start: CGPoint(x: center.x - 95 * scale, y: center.y - 100 * scale), end: CGPoint(x: center.x + 95 * scale, y: center.y + 115 * scale))
    context.restoreGState()
    stroke(context, RGBA(1, 1, 1, 0.62), path: path, width: 5 * scale)
}

private func drawSunRing(_ context: CGContext, center: CGPoint, radius: CGFloat, tint: RGBA = Palette.sun) {
    for index in 0..<4 {
        let inset = CGFloat(index) * radius * 0.18
        let alpha = 0.32 - CGFloat(index) * 0.06
        stroke(context, RGBA(tint.r, tint.g, tint.b, alpha), path: CGPath(ellipseIn: CGRect(x: center.x - radius + inset, y: center.y - radius + inset, width: (radius - inset) * 2, height: (radius - inset) * 2), transform: nil), width: max(2, radius * 0.035))
    }
    context.setFillColor(RGBA(tint.r, tint.g, tint.b, 0.92).cgColor)
    context.fillEllipse(in: CGRect(x: center.x - radius * 0.24, y: center.y - radius * 0.24, width: radius * 0.48, height: radius * 0.48))
}

private func drawHeroWelcome(_ context: CGContext, size: CGSize) {
    radial(context, colors: [RGBA(1, 0.71, 0.16, 0.32), RGBA(1, 0.71, 0.16, 0)], center: CGPoint(x: size.width * 0.28, y: size.height * 0.18), endRadius: size.width * 0.54)
    fill(context, RGBA(1, 1, 1, 0.40), in: CGRect(x: 92, y: 370, width: size.width - 184, height: 36))
    drawPhone(context, rect: CGRect(x: 432, y: 118, width: 182, height: 276), accent: Palette.aloe)
    drawBottle(context, center: CGPoint(x: 305, y: 260), scale: 0.88)
    fill(context, Palette.coral, in: CGRect(x: 192, y: 320, width: 124, height: 36))
    fill(context, RGBA(0.13, 0.11, 0.10, 0.20), in: CGRect(x: 650, y: 330, width: 104, height: 22))
    drawSunRing(context, center: CGPoint(x: 650, y: 160), radius: 54)
}

private func drawHeroNotification(_ context: CGContext, size: CGSize) {
    radial(context, colors: [RGBA(0.26, 0.65, 0.85, 0.20), RGBA(0.26, 0.65, 0.85, 0)], center: CGPoint(x: size.width * 0.74, y: size.height * 0.2), endRadius: size.width * 0.5)
    drawPhone(context, rect: CGRect(x: 250, y: 100, width: 232, height: 352), accent: Palette.sun)
    drawBottle(context, center: CGPoint(x: 560, y: 305), scale: 0.72, labelColor: Palette.coral)
    drawSunRing(context, center: CGPoint(x: 225, y: 150), radius: 44, tint: Palette.aloe)
}

private func drawCalendar(_ context: CGContext, rect: CGRect) {
    context.addPath(roundedRect(rect, radius: 34))
    context.clip()
    gradient(context, colors: [Palette.white, RGBA(1, 0.94, 0.78)], start: rect.origin, end: CGPoint(x: rect.maxX, y: rect.maxY))
    context.resetClip()
    fill(context, Palette.sun, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 74))
    for row in 0..<4 {
        for column in 0..<5 {
            let x = rect.minX + 42 + CGFloat(column) * 52
            let y = rect.minY + 112 + CGFloat(row) * 42
            let color: RGBA = (row + column).isMultiple(of: 3) ? Palette.sun : RGBA(0.13, 0.11, 0.10, 0.12)
            fill(context, color, in: CGRect(x: x, y: y, width: 18, height: 18))
        }
    }
}

private func drawAchievementShelf(_ context: CGContext, size: CGSize) {
    fill(context, RGBA(1, 0.92, 0.72, 0.45), in: CGRect(x: 86, y: 310, width: size.width - 172, height: 34))
    for (index, color) in [Palette.sun, Palette.aloe, Palette.coral].enumerated() {
        drawBadge(context, center: CGPoint(x: 190 + CGFloat(index) * 110, y: 228), scale: 0.58, tint: color, accent: index == 1 ? Palette.pool : Palette.aloe)
    }
}

private func drawBadge(_ context: CGContext, center: CGPoint, scale: CGFloat, tint: RGBA, accent: RGBA) {
    let shieldScale = 1.72 * scale
    let path = shieldPath(center: CGPoint(x: center.x, y: center.y + 8 * scale), scale: shieldScale)

    radial(
        context,
        colors: [RGBA(tint.r, tint.g, tint.b, 0.22), RGBA(tint.r, tint.g, tint.b, 0)],
        center: center,
        endRadius: 188 * scale
    )

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: 18 * scale),
        blur: 26 * scale,
        color: RGBA(tint.r, tint.g, tint.b, 0.20).cgColor
    )
    context.addPath(path)
    context.clip()
    gradient(
        context,
        colors: [
            tint,
            RGBA(
                max((tint.r + accent.r) / 2 - 0.02, 0),
                max((tint.g + accent.g) / 2 - 0.02, 0),
                max((tint.b + accent.b) / 2 - 0.02, 0),
                1
            )
        ],
        start: CGPoint(x: center.x - 130 * scale, y: center.y - 172 * scale),
        end: CGPoint(x: center.x + 130 * scale, y: center.y + 172 * scale)
    )
    radial(
        context,
        colors: [RGBA(1, 1, 1, 0.34), RGBA(1, 1, 1, 0)],
        center: CGPoint(x: center.x - 64 * scale, y: center.y - 96 * scale),
        endRadius: 142 * scale
    )
    context.restoreGState()

    stroke(context, RGBA(1, 1, 1, 0.78), path: path, width: 9 * scale)

    let sunCenter = CGPoint(x: center.x, y: center.y - 18 * scale)
    context.setStrokeColor(RGBA(1, 1, 1, 0.78).cgColor)
    context.setLineWidth(9 * scale)
    context.setLineCap(.round)
    for index in 0..<8 {
        let angle = CGFloat(index) * .pi / 4
        let start = CGPoint(
            x: sunCenter.x + cos(angle) * 54 * scale,
            y: sunCenter.y + sin(angle) * 54 * scale
        )
        let end = CGPoint(
            x: sunCenter.x + cos(angle) * 74 * scale,
            y: sunCenter.y + sin(angle) * 74 * scale
        )
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }
    context.setFillColor(RGBA(1, 1, 1, 0.92).cgColor)
    context.fillEllipse(in: CGRect(x: sunCenter.x - 40 * scale, y: sunCenter.y - 40 * scale, width: 80 * scale, height: 80 * scale))
}

private func strokeLine(_ context: CGContext, _ color: RGBA, from start: CGPoint, to end: CGPoint, width: CGFloat) {
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.move(to: start)
    context.addLine(to: end)
    context.strokePath()
}

private func drawPerson(
    _ context: CGContext,
    headCenter: CGPoint,
    torso: CGRect,
    shirt: RGBA,
    skin: RGBA
) {
    context.setFillColor(skin.cgColor)
    context.fillEllipse(in: CGRect(x: headCenter.x - 34, y: headCenter.y - 34, width: 68, height: 68))
    fillPath(
        context,
        skin,
        path: roundedRect(CGRect(x: headCenter.x - 17, y: torso.maxY - 10, width: 34, height: 34), radius: 12)
    )
    fillPath(context, shirt, path: roundedRect(torso, radius: 46))
    stroke(context, RGBA(1, 1, 1, 0.34), path: roundedRect(torso.insetBy(dx: 2, dy: 2), radius: 44), width: 3)
}

private func drawFriendsPair(_ context: CGContext, size: CGSize) {
    let card = CGRect(x: 102, y: 78, width: size.width - 204, height: size.height - 156)
    fillPath(context, RGBA(1, 1, 1, 0.82), path: roundedRect(card, radius: 38))
    stroke(context, RGBA(0.13, 0.11, 0.10, 0.08), path: roundedRect(card, radius: 38), width: 2)

    let tokenA = CGPoint(x: 226, y: 220)
    let tokenB = CGPoint(x: 374, y: 220)
    context.setFillColor(RGBA(Palette.sun.r, Palette.sun.g, Palette.sun.b, 0.16).cgColor)
    context.fillEllipse(in: CGRect(x: tokenA.x - 62, y: tokenA.y - 62, width: 124, height: 124))
    context.setFillColor(RGBA(Palette.aloe.r, Palette.aloe.g, Palette.aloe.b, 0.16).cgColor)
    context.fillEllipse(in: CGRect(x: tokenB.x - 62, y: tokenB.y - 62, width: 124, height: 124))
    context.setFillColor(Palette.sun.cgColor)
    context.fillEllipse(in: CGRect(x: tokenA.x - 34, y: tokenA.y - 34, width: 68, height: 68))
    context.setFillColor(Palette.aloe.cgColor)
    context.fillEllipse(in: CGRect(x: tokenB.x - 34, y: tokenB.y - 34, width: 68, height: 68))

    let center = CGPoint(x: 300, y: 220)
    drawSunRing(context, center: center, radius: 42, tint: Palette.warmGlow)
    strokeLine(context, RGBA(0.13, 0.11, 0.10, 0.16), from: CGPoint(x: tokenA.x + 42, y: tokenA.y), to: CGPoint(x: center.x - 34, y: center.y), width: 5)
    strokeLine(context, RGBA(0.13, 0.11, 0.10, 0.16), from: CGPoint(x: center.x + 34, y: center.y), to: CGPoint(x: tokenB.x - 42, y: tokenB.y), width: 5)

    fill(context, RGBA(0.13, 0.11, 0.10, 0.10), in: CGRect(x: card.minX + 74, y: card.minY + 62, width: card.width - 148, height: 10))
    fill(context, RGBA(0.13, 0.11, 0.10, 0.06), in: CGRect(x: card.minX + 118, y: card.minY + 84, width: card.width - 236, height: 10))
}

private func drawReport(_ context: CGContext, rect: CGRect) {
    fill(context, Palette.white, in: rect)
    fill(context, Palette.pool, in: CGRect(x: rect.minX + 30, y: rect.minY + 34, width: rect.width - 60, height: 18))
    for index in 0..<4 {
        fill(context, RGBA(0.13, 0.11, 0.10, 0.10), in: CGRect(x: rect.minX + 30, y: rect.minY + 84 + CGFloat(index) * 38, width: rect.width - 90 - CGFloat(index * 12), height: 12))
    }
    for index in 0..<5 {
        fill(context, index.isMultiple(of: 2) ? Palette.sun : Palette.aloe, in: CGRect(x: rect.minX + 36 + CGFloat(index) * 38, y: rect.maxY - 82 - CGFloat(index * 11), width: 24, height: 58 + CGFloat(index * 11)))
    }
}

private func renderPNG(_ spec: AssetSpec, scale: Int) throws -> Data {
    let width = spec.width * scale
    let height = spec.height * scale
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw NSError(domain: "SunclubVisualAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create \(scale)x bitmap context for \(spec.name)."])
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let logicalSize = CGSize(width: spec.width, height: spec.height)
    if spec.isOpaque {
        fill(context, Palette.cream, in: CGRect(origin: .zero, size: logicalSize))
    }
    spec.draw(context, logicalSize)

    guard let cgImage = context.makeImage() else {
        throw NSError(domain: "SunclubVisualAssets", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not make \(scale)x image for \(spec.name)."])
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SunclubVisualAssets", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode \(scale)x PNG for \(spec.name)."])
    }
    return png
}

private func filename(for spec: AssetSpec, scale: Int) -> String {
    scale == 1 ? "\(spec.name).png" : "\(spec.name)@\(scale)x.png"
}

private func drawAsset(_ spec: AssetSpec) throws {
    let imageset = assetCatalog.appendingPathComponent("\(spec.name).imageset", isDirectory: true)
    if FileManager.default.fileExists(atPath: imageset.path) {
        try FileManager.default.removeItem(at: imageset)
    }
    try FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)

    for scale in assetScales {
        let png = try renderPNG(spec, scale: scale)
        try png.write(to: imageset.appendingPathComponent(filename(for: spec, scale: scale)))
    }

    let imageEntries = assetScales.map { scale in
        """
            {
              "filename" : "\(filename(for: spec, scale: scale))",
              "idiom" : "universal",
              "scale" : "\(scale)x"
            }
        """
    }.joined(separator: ",\n")
    let contents = """
    {
      "images" : [
    \(imageEntries)
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try contents.data(using: .utf8)?.write(to: imageset.appendingPathComponent("Contents.json"))
}

private func specs() -> [AssetSpec] {
    let backgroundSize = (900, 1400)
    let illustrationSize = (600, 420)
    let heroSize = (900, 620)

    var result: [AssetSpec] = [
        AssetSpec(name: "BackgroundSunGrainLight", width: backgroundSize.0, height: backgroundSize.1, isOpaque: true) { context, size in
            drawLightLeakBackground(context, size: size, dark: false)
        },
        AssetSpec(name: "BackgroundSunGrainDark", width: backgroundSize.0, height: backgroundSize.1, isOpaque: true) { context, size in
            drawLightLeakBackground(context, size: size, dark: true)
        },
        AssetSpec(name: "BackgroundUVBands", width: 900, height: 500, isOpaque: false) { context, size in
            let colors = [
                RGBA(Palette.aloe.r, Palette.aloe.g, Palette.aloe.b, 0.32),
                RGBA(Palette.sun.r, Palette.sun.g, Palette.sun.b, 0.28),
                RGBA(Palette.coral.r, Palette.coral.g, Palette.coral.b, 0.22),
                RGBA(Palette.magenta.r, Palette.magenta.g, Palette.magenta.b, 0.18)
            ]
            for (index, color) in colors.enumerated() {
                let rect = CGRect(
                    x: 54 + CGFloat(index) * 34,
                    y: 80 + CGFloat(index) * 70,
                    width: size.width - 108 - CGFloat(index) * 68,
                    height: 42
                )
                fillPath(context, color, path: roundedRect(rect, radius: 21))
            }
            drawGrain(context, size: size, seed: 77, alpha: 0.025)
        },
        AssetSpec(name: "HeroWelcomeMorningKit", width: heroSize.0, height: heroSize.1, isOpaque: false) { context, size in
            drawHeroWelcome(context, size: size)
        },
        AssetSpec(name: "HeroNotificationNudge", width: heroSize.0, height: heroSize.1, isOpaque: false) { context, size in
            drawHeroNotification(context, size: size)
        },
        AssetSpec(name: "IllustrationLogBottle", width: illustrationSize.0, height: illustrationSize.1, isOpaque: false) { context, _ in
            drawBottle(context, center: CGPoint(x: 300, y: 215), scale: 0.9)
            drawSunRing(context, center: CGPoint(x: 410, y: 118), radius: 38, tint: Palette.aloe)
        },
        AssetSpec(name: "IllustrationScannerLabel", width: illustrationSize.0, height: illustrationSize.1, isOpaque: false) { context, _ in
            let card = CGRect(x: 130, y: 104, width: 340, height: 212)
            fillPath(context, RGBA(1, 1, 1, 0.92), path: roundedRect(card, radius: 28))
            stroke(context, RGBA(Palette.sun.r, Palette.sun.g, Palette.sun.b, 0.58), path: roundedRect(card, radius: 28), width: 4)
            fillPath(context, RGBA(Palette.sun.r, Palette.sun.g, Palette.sun.b, 0.12), path: roundedRect(CGRect(x: card.minX + 38, y: card.minY + 44, width: card.width - 76, height: 34), radius: 17))
            fill(context, RGBA(0.13, 0.11, 0.10, 0.12), in: CGRect(x: card.minX + 42, y: card.minY + 108, width: card.width - 108, height: 12))
            fill(context, RGBA(0.13, 0.11, 0.10, 0.08), in: CGRect(x: card.minX + 42, y: card.minY + 136, width: card.width - 152, height: 12))
            strokeLine(context, RGBA(Palette.pool.r, Palette.pool.g, Palette.pool.b, 0.72), from: CGPoint(x: card.minX + 34, y: card.midY), to: CGPoint(x: card.maxX - 34, y: card.midY), width: 3)
        },
        AssetSpec(name: "IllustrationHistoryCalendar", width: illustrationSize.0, height: illustrationSize.1, isOpaque: false) { context, _ in
            drawCalendar(context, rect: CGRect(x: 136, y: 82, width: 328, height: 266))
        },
        AssetSpec(name: "IllustrationAchievementsShelf", width: illustrationSize.0, height: illustrationSize.1, isOpaque: false) { context, size in
            drawAchievementShelf(context, size: size)
        },
        AssetSpec(name: "IllustrationFriendsPair", width: illustrationSize.0, height: illustrationSize.1, isOpaque: false) { context, size in
            drawFriendsPair(context, size: size)
        },
        AssetSpec(name: "IllustrationSkinReport", width: illustrationSize.0, height: illustrationSize.1, isOpaque: false) { context, _ in
            drawReport(context, rect: CGRect(x: 172, y: 66, width: 256, height: 308))
            drawShield(context, center: CGPoint(x: 430, y: 128), scale: 0.36, tint: Palette.aloe)
        },
        AssetSpec(name: "MotifSunRing", width: 640, height: 640, isOpaque: false) { context, _ in
            drawSunRing(context, center: CGPoint(x: 320, y: 320), radius: 250)
        },
        AssetSpec(name: "MotifShieldGlow", width: 640, height: 640, isOpaque: false) { context, _ in
            radial(context, colors: [RGBA(0.36, 0.72, 0.51, 0.42), RGBA(0.36, 0.72, 0.51, 0)], center: CGPoint(x: 320, y: 320), endRadius: 300)
            drawShield(context, center: CGPoint(x: 320, y: 320), scale: 1.0, tint: Palette.aloe)
        },
        AssetSpec(name: "MotifScanSheen", width: 500, height: 260, isOpaque: false) { context, size in
            gradient(context, colors: [RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 0.62), RGBA(1, 1, 1, 0)], start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0))
        },
        AssetSpec(name: "WidgetTextureWarm", width: 800, height: 800, isOpaque: true) { context, size in
            drawLightLeakBackground(context, size: size, dark: false)
        },
        AssetSpec(name: "WidgetTextureCool", width: 800, height: 800, isOpaque: true) { context, size in
            gradient(context, colors: [RGBA(0.94, 0.98, 1), RGBA(1, 0.96, 0.86), RGBA(0.86, 0.96, 0.90)], start: .zero, end: CGPoint(x: size.width, y: size.height))
            drawGrain(context, size: size, seed: 88, alpha: 0.05)
        },
        AssetSpec(name: "WidgetTextureNight", width: 800, height: 800, isOpaque: true) { context, size in
            drawLightLeakBackground(context, size: size, dark: true)
        },
        AssetSpec(name: "ShareCardBackdropWarm", width: 1080, height: 1350, isOpaque: true) { context, size in
            drawLightLeakBackground(context, size: size, dark: false)
        },
        AssetSpec(name: "ShareCardBackdropCool", width: 1080, height: 1350, isOpaque: true) { context, size in
            gradient(context, colors: [RGBA(0.14, 0.40, 0.52), RGBA(0.20, 0.58, 0.60), RGBA(0.96, 0.62, 0.18)], start: .zero, end: CGPoint(x: size.width, y: size.height))
            drawGrain(context, size: size, seed: 120, alpha: 0.08)
        },
        AssetSpec(name: "ShareCardBackdropAchievement", width: 1080, height: 1350, isOpaque: true) { context, size in
            gradient(context, colors: [RGBA(0.19, 0.13, 0.09), RGBA(0.67, 0.33, 0.08), RGBA(1.00, 0.76, 0.26)], start: .zero, end: CGPoint(x: size.width, y: size.height))
            radial(context, colors: [RGBA(1, 1, 1, 0.24), RGBA(1, 1, 1, 0)], center: CGPoint(x: size.width * 0.5, y: size.height * 0.32), endRadius: size.width * 0.48)
            drawGrain(context, size: size, seed: 150, alpha: 0.07)
        }
    ]

    let badges: [(String, RGBA, RGBA)] = [
        ("BadgeFirstLog", Palette.sun, Palette.aloe),
        ("BadgeThreeDay", Palette.aloe, Palette.sun),
        ("BadgeSevenDay", Palette.pool, Palette.sun),
        ("BadgeThirtyDay", Palette.coral, Palette.aloe),
        ("BadgeHighUV", Palette.magenta, Palette.sun),
        ("BadgeTraveler", Palette.pool, Palette.aloe),
        ("BadgeRecovery", Palette.aloe, Palette.pool),
        ("BadgePerfectWeek", Palette.sun, Palette.coral)
    ]

    for badge in badges {
        result.append(AssetSpec(name: badge.0, width: 512, height: 512, isOpaque: false) { context, _ in
            drawBadge(context, center: CGPoint(x: 256, y: 256), scale: 1.0, tint: badge.1, accent: badge.2)
        })
    }

    return result
}

try FileManager.default.createDirectory(at: assetCatalog, withIntermediateDirectories: true)
for spec in specs() {
    try drawAsset(spec)
    print("Generated \(spec.name)")
}
