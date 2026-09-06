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
// Apricot Morning: keep the store page aligned with the native app.
private let cocoa = NSColor(calibratedRed: 0.192, green: 0.145, blue: 0.122, alpha: 1)
private let muted = NSColor(calibratedRed: 0.459, green: 0.388, blue: 0.345, alpha: 1)

private func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = font.fontDescriptor.withDesign(.rounded) else { return font }
    return NSFont(descriptor: descriptor, size: size) ?? font
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

private func drawBackground(_ artwork: NSImage) {
    // Aspect-fill the photographic plate without distorting its materials.
    let scale = max(canvasSize.width / artwork.size.width, canvasSize.height / artwork.size.height)
    let size = CGSize(width: artwork.size.width * scale, height: artwork.size.height * scale)
    artwork.draw(
        in: CGRect(x: (canvasSize.width - size.width) / 2, y: (canvasSize.height - size.height) / 2,
                   width: size.width, height: size.height),
        from: .zero, operation: .copy, fraction: 1
    )
}

private func drawText(
    _ text: String,
    in rect: CGRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left,
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
    let phoneWidth: CGFloat = 1020
    let phoneHeight = (phoneWidth - 32) * (screenshot.size.height / screenshot.size.width) + 32
    let phoneRect = CGRect(
        x: (canvasSize.width - phoneWidth) / 2,
        y: 100,
        width: phoneWidth,
        height: phoneHeight
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.13)
    shadow.shadowBlurRadius = 42
    shadow.shadowOffset = CGSize(width: 0, height: -22)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: phoneRect, xRadius: 96, yRadius: 96).fill()
    NSGraphicsContext.restoreGraphicsState()

    let screenRect = phoneRect.insetBy(dx: 16, dy: 16)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screenRect, xRadius: 74, yRadius: 74).addClip()
    screenshot.draw(in: screenRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    NSColor.black.withAlphaComponent(0.08).setStroke()
    let borderPath = NSBezierPath(roundedRect: phoneRect, xRadius: 96, yRadius: 96)
    borderPath.lineWidth = 2
    borderPath.stroke()
}

private func compose(screen: Screen, artwork: NSImage, inputURL: URL, outputURL: URL) throws {
    guard FileManager.default.fileExists(atPath: inputURL.path) else {
        throw ComposeError.missingScreenshot(inputURL.path)
    }
    guard let screenshot = NSImage(contentsOf: inputURL), screenshot.isValid else {
        throw ComposeError.unreadableScreenshot(inputURL.path)
    }

    // Core Graphics needs four-byte rows for an opaque RGB drawing context.
    // A three-sample NSBitmapImageRep cannot back NSGraphicsContext reliably.
    guard let context = CGContext(
        data: nil, width: Int(canvasSize.width), height: Int(canvasSize.height),
        bitsPerComponent: 8, bytesPerRow: Int(canvasSize.width) * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw ComposeError.pngEncodingFailed(outputURL.path)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    drawBackground(artwork)
    drawText(
        "SUNCLUB  /  YOUR DAILY SPF RITUAL",
        in: CGRect(x: 100, y: 2720, width: 1120, height: 50),
        font: roundedFont(size: 28, weight: .semibold),
        color: muted
    )
    drawText(
        screen.headline,
        in: CGRect(x: 100, y: 2455, width: 1120, height: 250),
        font: roundedFont(size: 104, weight: .bold),
        color: cocoa
    )
    drawText(
        screen.caption,
        in: CGRect(x: 100, y: 2320, width: 1120, height: 110),
        font: roundedFont(size: 38, weight: .medium),
        color: muted,
        lineHeightMultiple: 1.08
    )
    drawPhoneFrame(with: screenshot)
    NSGraphicsContext.restoreGraphicsState()

    guard let result = context.makeImage(),
          let data = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:]) else {
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

    let artworkURL = manifestURL.deletingLastPathComponent().appendingPathComponent("assets/skincare-morning.png")
    guard let artwork = NSImage(contentsOf: artworkURL), artwork.isValid else {
        throw ComposeError.unreadableScreenshot(artworkURL.path)
    }

    for screen in screens {
        let inputURL = inputDirectory.appendingPathComponent("\(screen.id).png")
        let outputURL = outputDirectory.appendingPathComponent("\(screen.id).png")
        try compose(screen: screen, artwork: artwork, inputURL: inputURL, outputURL: outputURL)
    }
}

do {
    try run()
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
