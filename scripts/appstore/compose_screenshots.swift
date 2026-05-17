#!/usr/bin/env swift

import AppKit
import Foundation

private struct Screen {
    let id: String
    let headline: String
    let caption: String
}

private enum MarketingMotif {
    case loggingKit
    case uvForecast
    case reminder
    case weeklyReview
    case privacy
}

private struct MarketingStyle {
    let tag: String
    let proof: String
    let motif: MarketingMotif
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let accent: NSColor
    let secondaryAccent: NSColor
    let deepAccent: NSColor
    let ink: NSColor
    let muted: NSColor
    let phoneRect: CGRect
}

private enum ComposeError: LocalizedError {
    case usage
    case invalidManifest
    case missingScreenshot(String)
    case unreadableScreenshot(String)
    case pngEncodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: compose_screenshots.swift <metadata.json> <raw-input-dir> <output-dir>"
        case .invalidManifest:
            return "App Store metadata did not contain a valid assets.screenshots.screens array."
        case let .missingScreenshot(path):
            return "Missing raw screenshot: \(path)"
        case let .unreadableScreenshot(path):
            return "Could not read raw screenshot: \(path)"
        case let .pngEncodingFailed(path):
            return "Could not encode composed screenshot: \(path)"
        }
    }
}

private let canvasSize = CGSize(width: 1320, height: 2868)
private let canvasRect = CGRect(origin: .zero, size: canvasSize)
private let white = NSColor(calibratedWhite: 1, alpha: 1)
private let softWhite = NSColor(calibratedWhite: 1, alpha: 0.88)

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

private func parseScreens(from manifestURL: URL) throws -> [Screen] {
    let data = try Data(contentsOf: manifestURL)
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let assets = root["assets"] as? [String: Any],
          let screenshots = assets["screenshots"] as? [String: Any],
          let rawScreens = screenshots["screens"] as? [[String: Any]]
    else {
        throw ComposeError.invalidManifest
    }

    return try rawScreens.map { screen in
        guard let id = screen["id"] as? String else {
            throw ComposeError.invalidManifest
        }
        let headline = (screen["headline"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = (screen["caption"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let headline, let caption, !headline.isEmpty, !caption.isEmpty else {
            throw ComposeError.invalidManifest
        }
        return Screen(id: id, headline: headline, caption: caption)
    }
}

private func style(for screen: Screen, index: Int) -> MarketingStyle {
    let phoneWidth: CGFloat = 780
    let phoneRect = CGRect(
        x: (canvasSize.width - phoneWidth) / 2,
        y: 250,
        width: phoneWidth,
        height: phoneWidth * (canvasSize.height / canvasSize.width)
    )

    switch screen.id {
    case "log-spf":
        return MarketingStyle(
            tag: "Daily logging",
            proof: "SPF, timing, and covered areas",
            motif: .loggingKit,
            backgroundTop: color(255, 247, 226),
            backgroundBottom: color(238, 250, 246),
            accent: color(239, 132, 43),
            secondaryAccent: color(44, 168, 139),
            deepAccent: color(32, 84, 74),
            ink: color(24, 38, 49),
            muted: color(80, 92, 103),
            phoneRect: phoneRect
        )
    case "uv-timeline":
        return MarketingStyle(
            tag: "Live UV context",
            proof: "Peak hour and forecast at a glance",
            motif: .uvForecast,
            backgroundTop: color(230, 245, 255),
            backgroundBottom: color(255, 246, 219),
            accent: color(251, 178, 51),
            secondaryAccent: color(54, 117, 214),
            deepAccent: color(21, 62, 114),
            ink: color(19, 38, 61),
            muted: color(69, 86, 108),
            phoneRect: phoneRect
        )
    case "reapply-time":
        return MarketingStyle(
            tag: "Reminder routine",
            proof: "A quiet nudge when it matters",
            motif: .reminder,
            backgroundTop: color(246, 240, 255),
            backgroundBottom: color(225, 248, 244),
            accent: color(102, 89, 207),
            secondaryAccent: color(34, 166, 141),
            deepAccent: color(42, 42, 103),
            ink: color(30, 32, 64),
            muted: color(82, 82, 112),
            phoneRect: phoneRect
        )
    case "weekly-progress":
        return MarketingStyle(
            tag: "Weekly progress",
            proof: "See consistency without spreadsheets",
            motif: .weeklyReview,
            backgroundTop: color(237, 250, 236),
            backgroundBottom: color(255, 242, 224),
            accent: color(65, 154, 84),
            secondaryAccent: color(232, 119, 54),
            deepAccent: color(38, 87, 62),
            ink: color(22, 49, 39),
            muted: color(72, 91, 81),
            phoneRect: phoneRect
        )
    case "private-settings":
        return MarketingStyle(
            tag: "Private by default",
            proof: "No app account or ad tracking",
            motif: .privacy,
            backgroundTop: color(232, 241, 255),
            backgroundBottom: color(247, 238, 225),
            accent: color(28, 106, 174),
            secondaryAccent: color(229, 156, 67),
            deepAccent: color(18, 45, 78),
            ink: color(17, 38, 63),
            muted: color(72, 86, 101),
            phoneRect: phoneRect
        )
    default:
        let fallbackStyles = [
            ("Sun-smart routine", "Built from the real app", MarketingMotif.loggingKit),
            ("Daily context", "Current app screenshots inside", MarketingMotif.uvForecast),
            ("Better reminders", "Current app screenshots inside", MarketingMotif.reminder),
            ("Progress review", "Current app screenshots inside", MarketingMotif.weeklyReview),
            ("Private settings", "Current app screenshots inside", MarketingMotif.privacy),
        ]
        let fallback = fallbackStyles[index % fallbackStyles.count]
        return MarketingStyle(
            tag: fallback.0,
            proof: fallback.1,
            motif: fallback.2,
            backgroundTop: color(244, 248, 250),
            backgroundBottom: color(255, 244, 225),
            accent: color(235, 142, 44),
            secondaryAccent: color(37, 128, 162),
            deepAccent: color(30, 60, 86),
            ink: color(24, 38, 49),
            muted: color(80, 92, 103),
            phoneRect: phoneRect
        )
    }
}

private func drawCircle(in rect: CGRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

private func drawRoundedRect(
    _ rect: CGRect,
    radius: CGFloat,
    fill: NSColor,
    stroke: NSColor? = nil,
    lineWidth: CGFloat = 1
) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

private func drawRings(center: CGPoint, color: NSColor, count: Int = 4) {
    color.setStroke()
    for step in 0..<count {
        let radius = CGFloat(54 + step * 42)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = 9
        path.stroke()
    }
}

private func drawText(
    _ text: String,
    in rect: CGRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .center,
    lineHeightMultiple: CGFloat = 0.92
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineHeightMultiple = lineHeightMultiple

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    NSAttributedString(string: text, attributes: attributes).draw(
        with: rect,
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
}

private func drawMarketingBackground(style: MarketingStyle) {
    NSGradient(colors: [style.backgroundBottom, style.backgroundTop])?.draw(
        in: canvasRect,
        angle: 90
    )

    drawSunburst(center: CGPoint(x: 1085, y: 2468), color: style.accent)
    drawLayeredHorizon(style: style)
    drawCircle(
        in: CGRect(x: -230, y: 2050, width: 590, height: 590),
        color: style.secondaryAccent.withAlphaComponent(0.13)
    )
    drawRings(
        center: CGPoint(x: 165, y: 2385),
        color: white.withAlphaComponent(0.35),
        count: 5
    )
}

private func drawSunburst(center: CGPoint, color: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    color.withAlphaComponent(0.18).setStroke()
    for angle in stride(from: CGFloat(0), to: CGFloat.pi * 2, by: CGFloat.pi / 10) {
        let inner = CGPoint(
            x: center.x + cos(angle) * 145,
            y: center.y + sin(angle) * 145
        )
        let outer = CGPoint(
            x: center.x + cos(angle) * 430,
            y: center.y + sin(angle) * 430
        )
        let ray = NSBezierPath()
        ray.move(to: inner)
        ray.line(to: outer)
        ray.lineWidth = 12
        ray.lineCapStyle = .round
        ray.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    drawCircle(
        in: CGRect(x: center.x - 150, y: center.y - 150, width: 300, height: 300),
        color: color.withAlphaComponent(0.22)
    )
    drawCircle(
        in: CGRect(x: center.x - 88, y: center.y - 88, width: 176, height: 176),
        color: color.withAlphaComponent(0.32)
    )
}

private func drawLayeredHorizon(style: MarketingStyle) {
    for index in 0..<4 {
        let y = CGFloat(128 + index * 82)
        let path = NSBezierPath()
        path.move(to: CGPoint(x: -80, y: y))
        path.curve(
            to: CGPoint(x: 1400, y: y + CGFloat(index * 18) + 38),
            controlPoint1: CGPoint(x: 320, y: y + 118),
            controlPoint2: CGPoint(x: 890, y: y - 86)
        )
        path.line(to: CGPoint(x: 1400, y: 0))
        path.line(to: CGPoint(x: -80, y: 0))
        path.close()
        (index.isMultiple(of: 2) ? style.secondaryAccent : style.accent)
            .withAlphaComponent(0.10 + CGFloat(index) * 0.025)
            .setFill()
        path.fill()
    }
}

private func drawSceneArt(style: MarketingStyle) {
    drawRoundedRect(
        CGRect(x: 96, y: 560, width: 1128, height: 1260),
        radius: 86,
        fill: softWhite.withAlphaComponent(0.34),
        stroke: white.withAlphaComponent(0.42),
        lineWidth: 2
    )

    switch style.motif {
    case .loggingKit:
        drawLoggingKit(style: style)
    case .uvForecast:
        drawUVForecast(style: style)
    case .reminder:
        drawReminderSystem(style: style)
    case .weeklyReview:
        drawWeeklyReview(style: style)
    case .privacy:
        drawPrivacyShield(style: style)
    }
}

private func drawLoggingKit(style: MarketingStyle) {
    drawRoundedRect(CGRect(x: 116, y: 730, width: 220, height: 560), radius: 54, fill: white.withAlphaComponent(0.72))
    drawRoundedRect(CGRect(x: 170, y: 1260, width: 112, height: 70), radius: 24, fill: style.deepAccent.withAlphaComponent(0.85))
    drawRoundedRect(CGRect(x: 154, y: 902, width: 144, height: 245), radius: 34, fill: style.accent.withAlphaComponent(0.20))
    drawText(
        "SPF\n50",
        in: CGRect(x: 154, y: 954, width: 144, height: 135),
        font: NSFont.systemFont(ofSize: 44, weight: .heavy),
        color: style.deepAccent,
        lineHeightMultiple: 0.88
    )

    let rows = ["Face", "Arms", "Neck"]
    for (index, label) in rows.enumerated() {
        let y = CGFloat(1510 - index * 120)
        drawRoundedRect(CGRect(x: 934, y: y, width: 286, height: 88), radius: 32, fill: white.withAlphaComponent(0.72))
        drawCircle(in: CGRect(x: 968, y: y + 26, width: 36, height: 36), color: style.secondaryAccent)
        drawText(
            label,
            in: CGRect(x: 1022, y: y + 23, width: 150, height: 44),
            font: NSFont.systemFont(ofSize: 31, weight: .bold),
            color: style.ink,
            alignment: .left
        )
    }
}

private func drawUVForecast(style: MarketingStyle) {
    drawRings(center: CGPoint(x: 198, y: 1268), color: style.accent.withAlphaComponent(0.22), count: 6)
    drawCircle(in: CGRect(x: 102, y: 1172, width: 192, height: 192), color: style.accent.withAlphaComponent(0.34))

    let graph = NSBezierPath()
    graph.move(to: CGPoint(x: 920, y: 910))
    graph.curve(
        to: CGPoint(x: 1220, y: 1450),
        controlPoint1: CGPoint(x: 1015, y: 1020),
        controlPoint2: CGPoint(x: 1100, y: 1458)
    )
    graph.curve(
        to: CGPoint(x: 970, y: 1658),
        controlPoint1: CGPoint(x: 1190, y: 1604),
        controlPoint2: CGPoint(x: 1058, y: 1688)
    )
    style.secondaryAccent.withAlphaComponent(0.50).setStroke()
    graph.lineWidth = 26
    graph.lineCapStyle = .round
    graph.stroke()

    for index in 0..<5 {
        let height = CGFloat(82 + index * 38)
        drawRoundedRect(
            CGRect(x: 930 + CGFloat(index * 56), y: 720, width: 34, height: height),
            radius: 17,
            fill: (index < 3 ? style.accent : style.secondaryAccent).withAlphaComponent(0.42)
        )
    }
}

private func drawReminderSystem(style: MarketingStyle) {
    drawCircle(in: CGRect(x: 72, y: 950, width: 390, height: 390), color: white.withAlphaComponent(0.48))
    drawRings(center: CGPoint(x: 267, y: 1145), color: style.accent.withAlphaComponent(0.28), count: 3)
    style.deepAccent.withAlphaComponent(0.70).setStroke()
    let hand = NSBezierPath()
    hand.move(to: CGPoint(x: 267, y: 1145))
    hand.line(to: CGPoint(x: 267, y: 1260))
    hand.move(to: CGPoint(x: 267, y: 1145))
    hand.line(to: CGPoint(x: 348, y: 1096))
    hand.lineWidth = 14
    hand.lineCapStyle = .round
    hand.stroke()

    for (index, text) in ["Apply", "Reapply", "Done"].enumerated() {
        let y = CGFloat(1538 - index * 128)
        drawRoundedRect(CGRect(x: 910, y: y, width: 310, height: 94), radius: 34, fill: white.withAlphaComponent(0.76))
        drawText(
            text,
            in: CGRect(x: 950, y: y + 25, width: 190, height: 42),
            font: NSFont.systemFont(ofSize: 31, weight: .bold),
            color: style.ink,
            alignment: .left
        )
    }
}

private func drawWeeklyReview(style: MarketingStyle) {
    let startX: CGFloat = 116
    let startY: CGFloat = 1230
    for row in 0..<3 {
        for column in 0..<4 {
            let rect = CGRect(
                x: startX + CGFloat(column * 86),
                y: startY - CGFloat(row * 86),
                width: 62,
                height: 62
            )
            let active = row * 4 + column < 8
            drawRoundedRect(
                rect,
                radius: 20,
                fill: active ? style.accent.withAlphaComponent(0.48) : white.withAlphaComponent(0.62)
            )
        }
    }

    for (index, value) in ["4", "7", "12"].enumerated() {
        let x = CGFloat(930 + index * 98)
        drawCircle(in: CGRect(x: x, y: 1502, width: 78, height: 78), color: white.withAlphaComponent(0.72))
        drawText(
            value,
            in: CGRect(x: x, y: 1518, width: 78, height: 44),
            font: NSFont.systemFont(ofSize: 34, weight: .heavy),
            color: style.deepAccent
        )
    }
}

private func drawPrivacyShield(style: MarketingStyle) {
    let shield = NSBezierPath()
    shield.move(to: CGPoint(x: 234, y: 1588))
    shield.line(to: CGPoint(x: 404, y: 1514))
    shield.line(to: CGPoint(x: 372, y: 1178))
    shield.curve(
        to: CGPoint(x: 234, y: 964),
        controlPoint1: CGPoint(x: 354, y: 1088),
        controlPoint2: CGPoint(x: 302, y: 1014)
    )
    shield.curve(
        to: CGPoint(x: 96, y: 1178),
        controlPoint1: CGPoint(x: 166, y: 1014),
        controlPoint2: CGPoint(x: 114, y: 1088)
    )
    shield.line(to: CGPoint(x: 64, y: 1514))
    shield.close()
    white.withAlphaComponent(0.66).setFill()
    shield.fill()
    style.secondaryAccent.withAlphaComponent(0.36).setStroke()
    shield.lineWidth = 5
    shield.stroke()

    drawRoundedRect(CGRect(x: 170, y: 1194, width: 128, height: 104), radius: 26, fill: style.deepAccent.withAlphaComponent(0.82))
    style.deepAccent.withAlphaComponent(0.82).setStroke()
    let shackle = NSBezierPath()
    shackle.appendArc(withCenter: CGPoint(x: 234, y: 1304), radius: 52, startAngle: 0, endAngle: 180)
    shackle.lineWidth = 18
    shackle.stroke()

    for index in 0..<4 {
        drawRoundedRect(
            CGRect(x: 912, y: 1440 - CGFloat(index * 118), width: 310, height: 78),
            radius: 28,
            fill: white.withAlphaComponent(index == 0 ? 0.78 : 0.56)
        )
    }
}

private func drawHeader(screen: Screen, style: MarketingStyle) {
    drawRoundedRect(
        CGRect(x: 446, y: 2652, width: 428, height: 70),
        radius: 35,
        fill: white.withAlphaComponent(0.70),
        stroke: white.withAlphaComponent(0.75)
    )
    drawCircle(in: CGRect(x: 475, y: 2670, width: 34, height: 34), color: style.accent)
    drawText(
        "Sunclub  |  \(style.tag)",
        in: CGRect(x: 524, y: 2669, width: 315, height: 36),
        font: NSFont.systemFont(ofSize: 24, weight: .bold),
        color: style.deepAccent,
        alignment: .left
    )
    drawText(
        screen.headline,
        in: CGRect(x: 94, y: 2420, width: 1132, height: 210),
        font: NSFont.systemFont(ofSize: 92, weight: .heavy),
        color: style.ink
    )
    drawText(
        screen.caption,
        in: CGRect(x: 148, y: 2296, width: 1024, height: 96),
        font: NSFont.systemFont(ofSize: 38, weight: .semibold),
        color: style.muted,
        lineHeightMultiple: 1.08
    )
}

private func drawMarketingBadges(style: MarketingStyle) {
    drawCallout(
        title: style.tag,
        body: style.proof,
        rect: CGRect(x: 82, y: 1710, width: 366, height: 142),
        style: style
    )
    drawCallout(
        title: "Real app screen",
        body: "Captured from the current build",
        rect: CGRect(x: 872, y: 720, width: 366, height: 142),
        style: style
    )
}

private func drawCallout(title: String, body: String, rect: CGRect, style: MarketingStyle) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.10)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = CGSize(width: 0, height: -10)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    drawRoundedRect(rect, radius: 34, fill: white.withAlphaComponent(0.86))
    NSGraphicsContext.restoreGraphicsState()

    drawRoundedRect(
        CGRect(x: rect.minX + 24, y: rect.minY + 87, width: 54, height: 22),
        radius: 11,
        fill: style.accent.withAlphaComponent(0.75)
    )
    drawText(
        title,
        in: CGRect(x: rect.minX + 96, y: rect.minY + 79, width: rect.width - 124, height: 34),
        font: NSFont.systemFont(ofSize: 25, weight: .heavy),
        color: style.ink,
        alignment: .left
    )
    drawText(
        body,
        in: CGRect(x: rect.minX + 28, y: rect.minY + 26, width: rect.width - 56, height: 48),
        font: NSFont.systemFont(ofSize: 21, weight: .semibold),
        color: style.muted,
        alignment: .left,
        lineHeightMultiple: 1.06
    )
}

private func drawPhoneFrame(with screenshot: NSImage, in phoneRect: CGRect, style: MarketingStyle) {
    let shadow = NSShadow()
    shadow.shadowColor = style.deepAccent.withAlphaComponent(0.27)
    shadow.shadowBlurRadius = 58
    shadow.shadowOffset = CGSize(width: 0, height: -28)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    color(18, 23, 30).setFill()
    NSBezierPath(roundedRect: phoneRect, xRadius: 88, yRadius: 88).fill()
    NSGraphicsContext.restoreGraphicsState()

    drawRoundedRect(
        phoneRect.insetBy(dx: 9, dy: 9),
        radius: 80,
        fill: color(33, 38, 44),
        stroke: white.withAlphaComponent(0.28),
        lineWidth: 2
    )

    let screenRect = phoneRect.insetBy(dx: 22, dy: 22)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screenRect, xRadius: 65, yRadius: 65).addClip()
    screenshot.draw(in: screenRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    let highlight = NSBezierPath(roundedRect: phoneRect.insetBy(dx: 4, dy: 4), xRadius: 84, yRadius: 84)
    white.withAlphaComponent(0.18).setStroke()
    highlight.lineWidth = 3
    highlight.stroke()

    let borderPath = NSBezierPath(roundedRect: phoneRect, xRadius: 88, yRadius: 88)
    NSColor.black.withAlphaComponent(0.20).setStroke()
    borderPath.lineWidth = 3
    borderPath.stroke()
}

private func drawCampaignPage(screen: Screen, index: Int, screenshot: NSImage) {
    let style = style(for: screen, index: index)
    drawMarketingBackground(style: style)
    drawSceneArt(style: style)
    drawHeader(screen: screen, style: style)
    drawPhoneFrame(with: screenshot, in: style.phoneRect, style: style)
    drawMarketingBadges(style: style)
}

private func compose(screen: Screen, index: Int, inputURL: URL, outputURL: URL) throws {
    guard FileManager.default.fileExists(atPath: inputURL.path) else {
        throw ComposeError.missingScreenshot(inputURL.path)
    }
    guard let screenshot = NSImage(contentsOf: inputURL), screenshot.isValid else {
        throw ComposeError.unreadableScreenshot(inputURL.path)
    }

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw ComposeError.pngEncodingFailed(outputURL.path)
    }
    bitmap.size = canvasSize

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    context?.shouldAntialias = true
    NSGraphicsContext.current = context
    drawCampaignPage(screen: screen, index: index, screenshot: screenshot)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw ComposeError.pngEncodingFailed(outputURL.path)
    }
    try data.write(to: outputURL, options: .atomic)
    print("Composed \(outputURL.path)")
}

private func run() throws {
    guard CommandLine.arguments.count == 4 else {
        throw ComposeError.usage
    }

    let manifestURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let inputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)

    let screens = try parseScreens(from: manifestURL)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    for (index, screen) in screens.enumerated() {
        let inputURL = inputDirectory.appendingPathComponent("\(screen.id).png")
        let outputURL = outputDirectory.appendingPathComponent("\(screen.id).png")
        try compose(screen: screen, index: index, inputURL: inputURL, outputURL: outputURL)
    }
}

do {
    try run()
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
