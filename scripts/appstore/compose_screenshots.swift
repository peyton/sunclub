#!/usr/bin/env swift

import AppKit
import Foundation

private struct Screen {
    let id: String
    let headline: String
    let caption: String
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
private let background = NSColor(calibratedRed: 0.965, green: 0.945, blue: 0.895, alpha: 1)
private let navy = NSColor(calibratedRed: 0.055, green: 0.095, blue: 0.16, alpha: 1)
private let muted = NSColor(calibratedRed: 0.27, green: 0.31, blue: 0.36, alpha: 1)

private let accentPalette: [(primary: NSColor, secondary: NSColor)] = [
    (
        NSColor(calibratedRed: 0.95, green: 0.62, blue: 0.13, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.86, blue: 0.34, alpha: 1)
    ),
    (
        NSColor(calibratedRed: 0.22, green: 0.47, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.18, alpha: 1)
    ),
    (
        NSColor(calibratedRed: 0.25, green: 0.62, blue: 0.38, alpha: 1),
        NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.88, alpha: 1)
    ),
    (
        NSColor(calibratedRed: 0.91, green: 0.56, blue: 0.15, alpha: 1),
        NSColor(calibratedRed: 0.11, green: 0.20, blue: 0.34, alpha: 1)
    ),
    (
        NSColor(calibratedRed: 0.14, green: 0.58, blue: 0.56, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.17, blue: 0.29, alpha: 1)
    ),
]

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

private func drawBackground(index: Int) {
    background.setFill()
    NSRect(origin: .zero, size: canvasSize).fill()

    let accents = accentPalette[index % accentPalette.count]
    drawCircle(
        in: CGRect(x: 830, y: 2280, width: 680, height: 680),
        color: accents.primary.withAlphaComponent(0.16)
    )
    drawCircle(
        in: CGRect(x: -240, y: -140, width: 640, height: 640),
        color: accents.secondary.withAlphaComponent(0.12)
    )
    drawRings(center: CGPoint(x: 1110, y: 560), color: accents.primary.withAlphaComponent(0.16))
    drawRings(center: CGPoint(x: 190, y: 2465), color: accents.secondary.withAlphaComponent(0.18))
}

private func drawCircle(in rect: CGRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

private func drawRings(center: CGPoint, color: NSColor) {
    color.setStroke()
    for radius in stride(from: CGFloat(54), through: CGFloat(190), by: CGFloat(42)) {
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

private func drawPhoneFrame(with screenshot: NSImage) {
    let phoneWidth: CGFloat = 930
    let phoneHeight = phoneWidth * (canvasSize.height / canvasSize.width)
    let phoneRect = CGRect(
        x: (canvasSize.width - phoneWidth) / 2,
        y: 150,
        width: phoneWidth,
        height: phoneHeight
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.shadowBlurRadius = 42
    shadow.shadowOffset = CGSize(width: 0, height: -22)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: phoneRect, xRadius: 96, yRadius: 96).fill()
    NSGraphicsContext.restoreGraphicsState()

    let screenRect = phoneRect.insetBy(dx: 24, dy: 24)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screenRect, xRadius: 74, yRadius: 74).addClip()
    screenshot.draw(in: screenRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    NSColor.black.withAlphaComponent(0.08).setStroke()
    let borderPath = NSBezierPath(roundedRect: phoneRect, xRadius: 96, yRadius: 96)
    borderPath.lineWidth = 2
    borderPath.stroke()
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
    drawBackground(index: index)
    drawText(
        screen.headline,
        in: CGRect(x: 100, y: 2418, width: 1120, height: 230),
        font: NSFont.systemFont(ofSize: 92, weight: .heavy),
        color: navy
    )
    drawText(
        screen.caption,
        in: CGRect(x: 155, y: 2310, width: 1010, height: 92),
        font: NSFont.systemFont(ofSize: 38, weight: .semibold),
        color: muted,
        lineHeightMultiple: 1.08
    )
    drawPhoneFrame(with: screenshot)
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
