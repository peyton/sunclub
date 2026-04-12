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

private func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

private func fill(_ context: CGContext, _ color: RGBA, in rect: CGRect) {
    context.setFillColor(color.cgColor)
    context.fill(rect)
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
    let bounds = CGRect(origin: .zero, size: size)
    if dark {
        gradient(context, colors: [Palette.night, Palette.nightAmber, RGBA(0.085, 0.075, 0.071)], start: .zero, end: CGPoint(x: size.width, y: size.height))
        radial(context, colors: [RGBA(1, 0.62, 0.18, 0.42), RGBA(1, 0.62, 0.18, 0)], center: CGPoint(x: size.width * 0.18, y: size.height * 0.1), endRadius: size.width * 0.65)
        radial(context, colors: [RGBA(0.95, 0.22, 0.3, 0.18), RGBA(0.95, 0.22, 0.3, 0)], center: CGPoint(x: size.width * 0.92, y: size.height * 0.72), endRadius: size.width * 0.58)
        drawGrain(context, size: size, seed: 44, alpha: 0.07)
    } else {
        gradient(context, colors: [Palette.cream, Palette.pearl, RGBA(1, 0.945, 0.825)], start: .zero, end: CGPoint(x: size.width, y: size.height))
        radial(context, colors: [RGBA(1, 0.72, 0.12, 0.42), RGBA(1, 0.72, 0.12, 0)], center: CGPoint(x: size.width * 0.14, y: size.height * 0.02), endRadius: size.width * 0.72)
        radial(context, colors: [RGBA(0.36, 0.72, 0.51, 0.18), RGBA(0.36, 0.72, 0.51, 0)], center: CGPoint(x: size.width * 0.88, y: size.height * 0.68), endRadius: size.width * 0.52)
        drawGrain(context, size: size, seed: 19, alpha: 0.06)
    }

    context.setBlendMode(.softLight)
    context.setFillColor(RGBA(1, 1, 1, dark ? 0.07 : 0.28).cgColor)
    context.fillEllipse(in: bounds.insetBy(dx: -size.width * 0.2, dy: size.height * 0.18).offsetBy(dx: -size.width * 0.3, dy: -size.height * 0.45))
    context.setBlendMode(.normal)
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
    fill(context, Palette.ink, in: rect)
    fill(context, Palette.pearl, in: rect.insetBy(dx: 9, dy: 11))
    let notification = CGRect(x: rect.minX + 24, y: rect.minY + 64, width: rect.width - 48, height: 72)
    context.addPath(roundedRect(notification, radius: 18))
    context.clip()
    gradient(context, colors: [RGBA(1, 1, 1, 0.96), RGBA(1, 0.93, 0.76, 0.96)], start: notification.origin, end: CGPoint(x: notification.maxX, y: notification.maxY))
    context.resetClip()
    fill(context, accent, in: CGRect(x: notification.minX + 16, y: notification.minY + 22, width: 28, height: 28))
    fill(context, RGBA(0.13, 0.11, 0.10, 0.18), in: CGRect(x: notification.minX + 56, y: notification.minY + 22, width: notification.width - 78, height: 8))
    fill(context, RGBA(0.13, 0.11, 0.10, 0.10), in: CGRect(x: notification.minX + 56, y: notification.minY + 38, width: notification.width - 112, height: 8))
}

private func drawShield(_ context: CGContext, center: CGPoint, scale: CGFloat, tint: RGBA = Palette.aloe) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x, y: center.y - 105 * scale))
    path.addCurve(to: CGPoint(x: center.x + 92 * scale, y: center.y - 58 * scale), control1: CGPoint(x: center.x + 34 * scale, y: center.y - 98 * scale), control2: CGPoint(x: center.x + 66 * scale, y: center.y - 82 * scale))
    path.addCurve(to: CGPoint(x: center.x + 58 * scale, y: center.y + 82 * scale), control1: CGPoint(x: center.x + 92 * scale, y: center.y + 26 * scale), control2: CGPoint(x: center.x + 78 * scale, y: center.y + 62 * scale))
    path.addCurve(to: CGPoint(x: center.x, y: center.y + 116 * scale), control1: CGPoint(x: center.x + 34 * scale, y: center.y + 102 * scale), control2: CGPoint(x: center.x + 14 * scale, y: center.y + 112 * scale))
    path.addCurve(to: CGPoint(x: center.x - 58 * scale, y: center.y + 82 * scale), control1: CGPoint(x: center.x - 14 * scale, y: center.y + 112 * scale), control2: CGPoint(x: center.x - 34 * scale, y: center.y + 102 * scale))
    path.addCurve(to: CGPoint(x: center.x - 92 * scale, y: center.y - 58 * scale), control1: CGPoint(x: center.x - 78 * scale, y: center.y + 62 * scale), control2: CGPoint(x: center.x - 92 * scale, y: center.y + 26 * scale))
    path.addCurve(to: CGPoint(x: center.x, y: center.y - 105 * scale), control1: CGPoint(x: center.x - 66 * scale, y: center.y - 82 * scale), control2: CGPoint(x: center.x - 34 * scale, y: center.y - 98 * scale))
    path.closeSubpath()

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
    fill(context, RGBA(tint.r, tint.g, tint.b, 0.92), in: CGRect(x: center.x - radius * 0.24, y: center.y - radius * 0.24, width: radius * 0.48, height: radius * 0.48))
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
    let radius = 104 * scale
    radial(context, colors: [RGBA(tint.r, tint.g, tint.b, 0.25), RGBA(tint.r, tint.g, tint.b, 0)], center: center, endRadius: radius * 1.55)

    let outer = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )
    context.saveGState()
    context.addEllipse(in: outer)
    context.clip()
    gradient(
        context,
        colors: [
            RGBA(1, 0.98, 0.90, 1),
            tint,
            RGBA(max(tint.r - 0.10, 0), max(tint.g - 0.10, 0), max(tint.b - 0.10, 0), 1)
        ],
        start: CGPoint(x: outer.minX, y: outer.minY),
        end: CGPoint(x: outer.maxX, y: outer.maxY)
    )
    radial(
        context,
        colors: [RGBA(1, 1, 1, 0.42), RGBA(1, 1, 1, 0)],
        center: CGPoint(x: center.x - radius * 0.34, y: center.y - radius * 0.36),
        endRadius: radius * 0.82
    )
    context.restoreGState()

    stroke(context, RGBA(1, 1, 1, 0.72), path: CGPath(ellipseIn: outer.insetBy(dx: 10 * scale, dy: 10 * scale), transform: nil), width: 7 * scale)
    stroke(context, RGBA(accent.r, accent.g, accent.b, 0.58), path: CGPath(ellipseIn: outer.insetBy(dx: 31 * scale, dy: 31 * scale), transform: nil), width: 5 * scale)

    drawShield(context, center: CGPoint(x: center.x, y: center.y + 8 * scale), scale: 0.64 * scale, tint: accent)
    drawSunRing(context, center: CGPoint(x: center.x + 48 * scale, y: center.y - 48 * scale), radius: 30 * scale, tint: Palette.warmGlow)

    fill(context, RGBA(1, 1, 1, 0.28), in: CGRect(x: center.x - radius * 0.42, y: center.y - radius * 0.50, width: radius * 0.48, height: radius * 0.12))
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

private func drawAsset(_ spec: AssetSpec) throws {
    let imageset = assetCatalog.appendingPathComponent("\(spec.name).imageset", isDirectory: true)
    if FileManager.default.fileExists(atPath: imageset.path) {
        try FileManager.default.removeItem(at: imageset)
    }
    try FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)

    let width = spec.width
    let height = spec.height
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
        throw NSError(domain: "SunclubVisualAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap context for \(spec.name)."])
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    if spec.isOpaque {
        fill(context, Palette.cream, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    spec.draw(context, CGSize(width: width, height: height))

    guard let cgImage = context.makeImage() else {
        throw NSError(domain: "SunclubVisualAssets", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not make image for \(spec.name)."])
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SunclubVisualAssets", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG for \(spec.name)."])
    }

    let filename = "\(spec.name).png"
    try png.write(to: imageset.appendingPathComponent(filename))
    let contents = """
    {
      "images" : [
        {
          "filename" : "\(filename)",
          "idiom" : "universal",
          "scale" : "1x"
        }
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
            gradient(context, colors: [RGBA(0.36, 0.72, 0.51, 0.55), RGBA(1, 0.78, 0.24, 0.58), RGBA(0.96, 0.36, 0.25, 0.48), RGBA(0.78, 0.25, 0.56, 0.38)], start: .zero, end: CGPoint(x: size.width, y: size.height))
            drawGrain(context, size: size, seed: 77, alpha: 0.045)
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
            fill(context, Palette.white, in: card)
            stroke(context, Palette.sun, path: roundedRect(card, radius: 28), width: 5)
            fill(context, Palette.pool, in: CGRect(x: card.minX + 38, y: card.minY + 48, width: card.width - 76, height: 28))
            fill(context, RGBA(0.13, 0.11, 0.10, 0.12), in: CGRect(x: card.minX + 38, y: card.minY + 96, width: card.width - 104, height: 16))
            fill(context, RGBA(0.13, 0.11, 0.10, 0.08), in: CGRect(x: card.minX + 38, y: card.minY + 126, width: card.width - 144, height: 16))
        },
        AssetSpec(name: "IllustrationHistoryCalendar", width: illustrationSize.0, height: illustrationSize.1, isOpaque: false) { context, _ in
            drawCalendar(context, rect: CGRect(x: 136, y: 82, width: 328, height: 266))
        },
        AssetSpec(name: "IllustrationAchievementsShelf", width: illustrationSize.0, height: illustrationSize.1, isOpaque: false) { context, size in
            drawAchievementShelf(context, size: size)
        },
        AssetSpec(name: "IllustrationFriendsPair", width: illustrationSize.0, height: illustrationSize.1, isOpaque: false) { context, _ in
            drawPhone(context, rect: CGRect(x: 160, y: 100, width: 138, height: 224), accent: Palette.sun)
            drawPhone(context, rect: CGRect(x: 302, y: 82, width: 138, height: 224), accent: Palette.aloe)
            stroke(context, RGBA(0.98, 0.64, 0.01, 0.46), path: CGPath(ellipseIn: CGRect(x: 260, y: 190, width: 84, height: 84), transform: nil), width: 5)
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
