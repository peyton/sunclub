import Foundation
import UIKit

enum SunclubShareArtifactService {
    static let appLinkDisplay = "sunclub.peyton.app"
    static let appShareURLString = "https://sunclub.peyton.app"

    private struct ShareTextStyle {
        var maximumFontSize: CGFloat
        var minimumFontSize: CGFloat
        var weight: UIFont.Weight
        var color: UIColor
        var alignment: NSTextAlignment
        var letterSpacing: CGFloat = 0
    }

    private struct CardRenderSpec {
        var seasonStyle: SunclubSeasonStyle
        var title: String
        var subtitle: String
        var heroValue: String
        var footer: String
    }

    static func makeStreakCard(
        currentStreak: Int,
        longestStreak: Int,
        recordedDays: [Date],
        seasonStyle: SunclubSeasonStyle,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> SunclubShareArtifact {
        let title = "\(max(currentStreak, 0))-day streak"
        let subtitle = "Sunclub consistency card"
        let heatmapDays = recentHeatmapDays(now: now, calendar: calendar)
        let recordedSet = Set(recordedDays.map { calendar.startOfDay(for: $0) })
        let image = renderCard(
            CardRenderSpec(
                seasonStyle: seasonStyle,
                title: title,
                subtitle: subtitle,
                heroValue: "Best \(longestStreak)",
                footer: "sunclub"
            )
        ) { context, bounds in
            drawHeatmap(
                in: CGRect(x: 40, y: 190, width: bounds.width - 80, height: 120),
                days: heatmapDays,
                recordedSet: recordedSet,
                calendar: calendar,
                context: context
            )
            drawBodyCopy(
                "Keep showing up. Every square is one protected day.",
                in: CGRect(x: 40, y: 330, width: bounds.width - 80, height: 70),
                font: .systemFont(ofSize: 20, weight: .medium),
                color: .white
            )
        }

        let fileURL = try writeImage(image, named: "sunclub-streak-card.png")
        return SunclubShareArtifact(title: title, subtitle: subtitle, fileURL: fileURL)
    }

    static func makeAchievementCard(
        achievement: SunclubAchievement,
        seasonStyle: SunclubSeasonStyle
    ) throws -> SunclubShareArtifact {
        let image = renderAchievementCard(achievement: achievement, seasonStyle: seasonStyle)
        // Keep this as display text so Messages does not replace the PNG with a rich link preview.
        let shareText = "\(achievement.shareBlurb) Build your sunscreen streak: \(appLinkDisplay)"

        let fileURL = try writeImage(image, named: "sunclub-achievement-\(achievement.id.rawValue).png")
        return SunclubShareArtifact(
            title: achievement.title,
            subtitle: achievement.shareBlurb,
            fileURL: fileURL,
            shareText: shareText
        )
    }

    static func makeChallengeCard(
        challenge: SunclubSeasonalChallenge,
        seasonStyle: SunclubSeasonStyle
    ) throws -> SunclubShareArtifact {
        let image = renderCard(
            CardRenderSpec(
                seasonStyle: seasonStyle,
                title: challenge.title,
                subtitle: challenge.isComplete ? "Challenge complete" : "Challenge in progress",
                heroValue: "\(challenge.currentValue)/\(challenge.targetValue)",
                footer: "sunclub"
            )
        ) { context, bounds in
            drawProgressBar(
                in: CGRect(x: 40, y: 220, width: bounds.width - 80, height: 18),
                progress: challenge.progress,
                context: context
            )
            drawBodyCopy(
                challenge.detail,
                in: CGRect(x: 40, y: 260, width: bounds.width - 80, height: 100),
                font: .systemFont(ofSize: 22, weight: .medium),
                color: .white
            )
        }

        let fileURL = try writeImage(image, named: "sunclub-challenge-\(challenge.id.rawValue).png")
        return SunclubShareArtifact(title: challenge.title, subtitle: challenge.detail, fileURL: fileURL)
    }

    static func makeSkinHealthReport(
        summary: SunclubSkinHealthReportSummary,
        preferredName: String
    ) throws -> SunclubShareArtifact {
        let title = "Skin Health Report"
        let subtitle = "Sunclub report for \(preferredName.isEmpty ? "your routine" : preferredName)"
        let fileURL = try temporaryURL(named: "sunclub-skin-health-report.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))

        try renderer.writePDF(to: fileURL) { context in
            context.beginPage()
            let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
            UIColor.systemBackground.setFill()
            context.cgContext.fill(bounds)

            drawTitle(
                title,
                subtitle: subtitle,
                in: CGRect(x: 40, y: 40, width: bounds.width - 80, height: 90),
                titleColor: UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1),
                subtitleColor: UIColor(red: 0.38, green: 0.34, blue: 0.30, alpha: 1)
            )

            drawMetricColumn(
                [
                    ("Protected days", "\(summary.totalProtectedDays)"),
                    ("Longest streak", "\(summary.longestStreak)"),
                    ("Average streak", String(format: "%.1f", summary.averageStreakLength)),
                    ("High-UV protected", "\(summary.highUVProtectedDays)")
                ],
                in: CGRect(x: 40, y: 150, width: bounds.width - 80, height: 150),
                inkColor: UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
            )

            drawMonthlyConsistency(
                summary.monthlyConsistency,
                in: CGRect(x: 40, y: 330, width: bounds.width - 80, height: 160)
            )

            drawSPFDistribution(
                summary.spfDistribution,
                mostUsedSPF: summary.mostUsedSPF,
                in: CGRect(x: 40, y: 520, width: bounds.width - 80, height: 180)
            )

            drawBodyCopy(
                "Generated on-device by Sunclub. Share this with your dermatologist if you want a snapshot of your routine.",
                in: CGRect(x: 40, y: 716, width: bounds.width - 80, height: 40),
                font: .systemFont(ofSize: 14, weight: .medium),
                color: UIColor(red: 0.38, green: 0.34, blue: 0.30, alpha: 1)
            )
        }

        return SunclubShareArtifact(title: title, subtitle: subtitle, fileURL: fileURL)
    }

    private static func renderAchievementCard(
        achievement: SunclubAchievement,
        seasonStyle: SunclubSeasonStyle
    ) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: 1080, height: 1350)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            drawAchievementBackground(in: bounds, context: context)
            drawAchievementPanel(in: CGRect(x: 96, y: 112, width: 888, height: 1126), context: context)
            drawAchievementSymbol(
                achievement,
                seasonStyle: seasonStyle,
                in: CGRect(x: 396, y: 342, width: 288, height: 288),
                context: context
            )
            drawAchievementText(achievement, context: context)
        }
    }

    private static func drawAchievementText(
        _ achievement: SunclubAchievement,
        context: CGContext
    ) {
        drawFittedText(
            "SUNCLUB",
            in: CGRect(x: 156, y: 190, width: 768, height: 42),
            style: achievementBrandTextStyle
        )
        drawCapsuleLabel(
            "Achievement unlocked",
            in: CGRect(x: 318, y: 258, width: 444, height: 72),
            context: context
        )
        drawFittedText(
            achievement.title,
            in: CGRect(x: 156, y: 690, width: 768, height: 128),
            style: achievementTitleTextStyle
        )
        drawFittedText(
            achievementStatusLine(for: achievement),
            in: CGRect(x: 186, y: 842, width: 708, height: 50),
            style: achievementStatusTextStyle
        )
        drawWrappedText(
            achievement.detail,
            in: CGRect(x: 188, y: 936, width: 704, height: 96),
            style: achievementDetailTextStyle,
            maximumLines: 2
        )
        drawFittedText(
            appLinkDisplay,
            in: CGRect(x: 156, y: 1116, width: 768, height: 42),
            style: achievementLinkTextStyle
        )
    }

    private static func renderCard(
        _ spec: CardRenderSpec,
        drawContent: (CGContext, CGRect) -> Void
    ) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: 1080, height: 1350)
        let renderer = UIGraphicsImageRenderer(bounds: bounds)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            drawBackground(in: bounds, seasonStyle: spec.seasonStyle, context: context)
            drawTitle(
                spec.title,
                subtitle: spec.subtitle,
                in: CGRect(x: 40, y: 44, width: bounds.width - 80, height: 120),
                titleColor: .white,
                subtitleColor: UIColor.white.withAlphaComponent(0.84)
            )
            drawHeroValue(
                spec.heroValue,
                in: CGRect(x: 40, y: 126, width: bounds.width - 80, height: 70),
                color: .white
            )
            drawContent(context, bounds)
            drawBodyCopy(
                spec.footer.uppercased(),
                in: CGRect(x: 40, y: bounds.height - 70, width: 240, height: 24),
                font: .systemFont(ofSize: 18, weight: .bold),
                color: UIColor.white.withAlphaComponent(0.9)
            )
        }
    }

    private static var achievementInk: UIColor {
        UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
    }

    private static var achievementSoftInk: UIColor {
        UIColor(red: 0.39, green: 0.31, blue: 0.25, alpha: 1)
    }

    private static var achievementAccent: UIColor {
        UIColor(red: 0.78, green: 0.31, blue: 0.11, alpha: 1)
    }

    private static var achievementCream: UIColor {
        UIColor(red: 1.00, green: 0.96, blue: 0.84, alpha: 1)
    }

    private static var achievementBrandTextStyle: ShareTextStyle {
        ShareTextStyle(
            maximumFontSize: 31,
            minimumFontSize: 25,
            weight: .bold,
            color: achievementInk,
            alignment: .center,
            letterSpacing: 2.8
        )
    }

    private static var achievementTitleTextStyle: ShareTextStyle {
        ShareTextStyle(
            maximumFontSize: 76,
            minimumFontSize: 44,
            weight: .bold,
            color: achievementInk,
            alignment: .center
        )
    }

    private static var achievementStatusTextStyle: ShareTextStyle {
        ShareTextStyle(
            maximumFontSize: 34,
            minimumFontSize: 26,
            weight: .semibold,
            color: achievementAccent,
            alignment: .center
        )
    }

    private static var achievementDetailTextStyle: ShareTextStyle {
        ShareTextStyle(
            maximumFontSize: 30,
            minimumFontSize: 24,
            weight: .medium,
            color: achievementSoftInk,
            alignment: .center
        )
    }

    private static var achievementLinkTextStyle: ShareTextStyle {
        ShareTextStyle(
            maximumFontSize: 30,
            minimumFontSize: 24,
            weight: .semibold,
            color: achievementInk,
            alignment: .center
        )
    }

    private static func drawAchievementBackground(
        in bounds: CGRect,
        context: CGContext
    ) {
        if drawAssetBackdrop(SunclubVisualAsset.shareCardBackdropAchievement.rawValue, in: bounds) {
            return
        }

        let colors = [
            UIColor(red: 1.00, green: 0.72, blue: 0.16, alpha: 1),
            UIColor(red: 0.98, green: 0.50, blue: 0.12, alpha: 1),
            UIColor(red: 0.92, green: 0.24, blue: 0.18, alpha: 1)
        ]
        let cgColors = colors.map(\.cgColor) as CFArray
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: cgColors,
            locations: [0, 0.55, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: bounds.width, y: bounds.height),
            options: []
        )

        UIColor.white.withAlphaComponent(0.18).setFill()
        context.fillEllipse(in: CGRect(x: bounds.width - 292, y: 86, width: 252, height: 252))
        context.fillEllipse(in: CGRect(x: -86, y: bounds.height - 276, width: 330, height: 330))
    }

    private static func drawAchievementPanel(
        in rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 22),
            blur: 48,
            color: UIColor(red: 0.41, green: 0.16, blue: 0.07, alpha: 0.18).cgColor
        )
        achievementCream.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 62).fill()
        context.restoreGState()

        UIColor.white.withAlphaComponent(0.58).setStroke()
        let strokeRect = rect.insetBy(dx: 1.5, dy: 1.5)
        UIBezierPath(roundedRect: strokeRect, cornerRadius: 60).stroke()
    }

    private static func drawAchievementSymbol(
        _ achievement: SunclubAchievement,
        seasonStyle: SunclubSeasonStyle,
        in rect: CGRect,
        context: CGContext
    ) {
        if let badge = UIImage(named: achievement.id.visualAsset.rawValue) {
            badge.draw(in: rect.insetBy(dx: -10, dy: -10))
            return
        }

        let badgeColors: [UIColor]
        switch seasonStyle {
        case .summerGlow:
            badgeColors = [
                UIColor(red: 1.00, green: 0.78, blue: 0.20, alpha: 1),
                UIColor(red: 0.95, green: 0.35, blue: 0.17, alpha: 1)
            ]
        case .winterShield:
            badgeColors = [
                UIColor(red: 0.48, green: 0.73, blue: 0.93, alpha: 1),
                UIColor(red: 0.13, green: 0.33, blue: 0.56, alpha: 1)
            ]
        }

        context.saveGState()
        let path = UIBezierPath(ovalIn: rect)
        path.addClip()
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: badgeColors.map(\.cgColor) as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
        context.restoreGState()

        UIColor.white.withAlphaComponent(0.32).setStroke()
        UIBezierPath(ovalIn: rect.insetBy(dx: 8, dy: 8)).stroke()

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 132, weight: .bold)
        let symbol = UIImage(systemName: achievement.symbolName, withConfiguration: symbolConfig)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        let symbolSize = CGSize(width: 154, height: 154)
        symbol?.draw(in: CGRect(
            x: rect.midX - symbolSize.width / 2,
            y: rect.midY - symbolSize.height / 2,
            width: symbolSize.width,
            height: symbolSize.height
        ))
    }

    private static func drawCapsuleLabel(
        _ text: String,
        in rect: CGRect,
        context: CGContext
    ) {
        UIColor.white.withAlphaComponent(0.76).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
        UIColor(red: 0.78, green: 0.31, blue: 0.11, alpha: 0.16).setStroke()
        UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: (rect.height - 2) / 2).stroke()

        drawFittedText(
            text,
            in: rect.insetBy(dx: 30, dy: 15),
            style: ShareTextStyle(
                maximumFontSize: 28,
                minimumFontSize: 22,
                weight: .semibold,
                color: achievementAccent,
                alignment: .center
            )
        )
    }

    private static func achievementStatusLine(for achievement: SunclubAchievement) -> String {
        switch achievement.id {
        case .streak7, .streak30, .streak100, .streak365:
            let dayLabel = achievement.currentValue == 1 ? "day" : "days"
            return "Longest streak: \(achievement.currentValue) \(dayLabel)"
        case .firstReapply, .firstBackfill, .summerSurvivor, .winterWarrior, .morningGlow, .weekendCanopy,
             .spfSampler, .noteTaker, .reapplyRelay, .highUVHero, .homeBase, .liveSignal, .bottleDetective,
             .socialSpark:
            return achievement.isUnlocked ? "Unlocked" : "\(achievement.currentValue)/\(achievement.targetValue)"
        }
    }

    private static func drawBackground(
        in bounds: CGRect,
        seasonStyle: SunclubSeasonStyle,
        context: CGContext
    ) {
        let assetName: String = switch seasonStyle {
        case .summerGlow:
            SunclubVisualAsset.shareCardBackdropWarm.rawValue
        case .winterShield:
            SunclubVisualAsset.shareCardBackdropCool.rawValue
        }
        if drawAssetBackdrop(assetName, in: bounds) {
            return
        }

        let colors: [UIColor]
        switch seasonStyle {
        case .summerGlow:
            colors = [
                UIColor(red: 0.98, green: 0.58, blue: 0.16, alpha: 1),
                UIColor(red: 0.98, green: 0.81, blue: 0.20, alpha: 1),
                UIColor(red: 0.96, green: 0.35, blue: 0.25, alpha: 1)
            ]
        case .winterShield:
            colors = [
                UIColor(red: 0.10, green: 0.23, blue: 0.42, alpha: 1),
                UIColor(red: 0.26, green: 0.52, blue: 0.77, alpha: 1),
                UIColor(red: 0.76, green: 0.88, blue: 0.97, alpha: 1)
            ]
        }

        let cgColors = colors.map(\.cgColor) as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: [0, 0.5, 1])!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: bounds.width, y: bounds.height), options: [])

        UIColor.white.withAlphaComponent(0.12).setFill()
        context.fillEllipse(in: CGRect(x: bounds.width - 280, y: 80, width: 220, height: 220))
        context.fillEllipse(in: CGRect(x: -60, y: bounds.height - 240, width: 280, height: 280))
    }

    @discardableResult
    private static func drawAssetBackdrop(_ name: String, in bounds: CGRect) -> Bool {
        guard let image = UIImage(named: name) else {
            return false
        }

        image.draw(in: bounds)
        UIColor.white.withAlphaComponent(0.08).setFill()
        UIBezierPath(rect: bounds).fill()
        return true
    }

    private static func drawTitle(
        _ title: String,
        subtitle: String,
        in rect: CGRect,
        titleColor: UIColor,
        subtitleColor: UIColor
    ) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 58, weight: .bold),
            .foregroundColor: titleColor
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: subtitleColor
        ]

        (title as NSString).draw(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 64), withAttributes: titleAttributes)
        (subtitle as NSString).draw(in: CGRect(x: rect.minX, y: rect.minY + 72, width: rect.width, height: 40), withAttributes: subtitleAttributes)
    }

    private static func drawHeroValue(
        _ value: String,
        in rect: CGRect,
        color: UIColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
            .foregroundColor: color
        ]
        (value as NSString).draw(in: rect, withAttributes: attributes)
    }

    private static func drawHeatmap(
        in rect: CGRect,
        days: [Date],
        recordedSet: Set<Date>,
        calendar: Calendar,
        context: CGContext
    ) {
        let columns = 7
        let cellSize = CGSize(width: (rect.width - CGFloat(columns - 1) * 10) / CGFloat(columns), height: 46)
        for (index, day) in days.enumerated() {
            let row = index / columns
            let column = index % columns
            let cellRect = CGRect(
                x: rect.minX + CGFloat(column) * (cellSize.width + 10),
                y: rect.minY + CGFloat(row) * (cellSize.height + 10),
                width: cellSize.width,
                height: cellSize.height
            )
            let normalizedDay = calendar.startOfDay(for: day)
            let isRecorded = recordedSet.contains(normalizedDay)
            let fillColor = isRecorded
                ? UIColor.white.withAlphaComponent(0.95)
                : UIColor.white.withAlphaComponent(0.24)
            context.setFillColor(fillColor.cgColor)
            let path = UIBezierPath(roundedRect: cellRect, cornerRadius: 14)
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }

    private static func drawProgressBar(
        in rect: CGRect,
        progress: Double,
        context: CGContext
    ) {
        let backgroundPath = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        UIColor.white.withAlphaComponent(0.22).setFill()
        backgroundPath.fill()

        let fillRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width * CGFloat(progress), height: rect.height)
        let fillPath = UIBezierPath(roundedRect: fillRect, cornerRadius: rect.height / 2)
        UIColor.white.withAlphaComponent(0.9).setFill()
        fillPath.fill()
    }

    private static func drawMetricColumn(
        _ rows: [(String, String)],
        in rect: CGRect,
        inkColor: UIColor
    ) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: inkColor.withAlphaComponent(0.7)
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: inkColor
        ]

        let columnWidth = rect.width / 2
        for (index, row) in rows.enumerated() {
            let rowIndex = index / 2
            let columnIndex = index % 2
            let origin = CGPoint(
                x: rect.minX + CGFloat(columnIndex) * columnWidth,
                y: rect.minY + CGFloat(rowIndex) * 68
            )
            (row.0 as NSString).draw(
                in: CGRect(x: origin.x, y: origin.y, width: columnWidth - 16, height: 22),
                withAttributes: labelAttributes
            )
            (row.1 as NSString).draw(
                in: CGRect(x: origin.x, y: origin.y + 24, width: columnWidth - 16, height: 36),
                withAttributes: valueAttributes
            )
        }
    }

    private static func drawMonthlyConsistency(
        _ entries: [SunclubMonthlyConsistencyEntry],
        in rect: CGRect
    ) {
        drawBodyCopy(
            "Monthly consistency heatmap",
            in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 20),
            font: .systemFont(ofSize: 18, weight: .semibold),
            color: UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
        )

        let cellWidth = (rect.width - 22) / 6
        let cellHeight: CGFloat = 54
        for (index, entry) in entries.enumerated() {
            let row = index / 6
            let column = index % 6
            let cellRect = CGRect(
                x: rect.minX + CGFloat(column) * (cellWidth + 4),
                y: rect.minY + 32 + CGFloat(row) * (cellHeight + 8),
                width: cellWidth,
                height: cellHeight
            )
            let fill = UIColor(
                red: 0.98,
                green: 0.76 - (0.24 * entry.ratio),
                blue: 0.30 - (0.10 * entry.ratio),
                alpha: 0.85
            )
            fill.setFill()
            UIBezierPath(roundedRect: cellRect, cornerRadius: 14).fill()

            drawBodyCopy(
                entry.monthLabel,
                in: CGRect(x: cellRect.minX + 10, y: cellRect.minY + 8, width: cellRect.width - 20, height: 16),
                font: .systemFont(ofSize: 13, weight: .semibold),
                color: .white
            )
            drawBodyCopy(
                "\(entry.protectedDays)/\(entry.totalDays)",
                in: CGRect(x: cellRect.minX + 10, y: cellRect.minY + 26, width: cellRect.width - 20, height: 18),
                font: .systemFont(ofSize: 14, weight: .medium),
                color: .white
            )
        }
    }

    private static func drawSPFDistribution(
        _ entries: [SunclubSPFDistributionEntry],
        mostUsedSPF: MostUsedSPFInsight?,
        in rect: CGRect
    ) {
        drawBodyCopy(
            "SPF distribution",
            in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 20),
            font: .systemFont(ofSize: 18, weight: .semibold),
            color: UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
        )

        let topEntries = Array(entries.prefix(4))
        for (index, entry) in topEntries.enumerated() {
            let rowOriginY = rect.minY + 34 + CGFloat(index) * 30
            drawBodyCopy(
                "SPF \(entry.spf)",
                in: CGRect(x: rect.minX, y: rowOriginY, width: 120, height: 20),
                font: .systemFont(ofSize: 16, weight: .medium),
                color: UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
            )
            drawBodyCopy(
                "\(entry.count) check-ins",
                in: CGRect(x: rect.minX + 140, y: rowOriginY, width: rect.width - 140, height: 20),
                font: .systemFont(ofSize: 16, weight: .regular),
                color: UIColor(red: 0.38, green: 0.34, blue: 0.30, alpha: 1)
            )
        }

        if let mostUsedSPF {
            drawBodyCopy(
                "Most used: \(mostUsedSPF.title) (\(mostUsedSPF.count) of \(mostUsedSPF.totalLoggedCount))",
                in: CGRect(x: rect.minX, y: rect.maxY - 28, width: rect.width, height: 22),
                font: .systemFont(ofSize: 16, weight: .semibold),
                color: UIColor(red: 0.87, green: 0.43, blue: 0.05, alpha: 1)
            )
        }
    }

    private static func drawBodyCopy(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private static func drawFittedText(
        _ text: String,
        in rect: CGRect,
        style: ShareTextStyle
    ) {
        var fontSize = style.maximumFontSize
        var attributes = fittedTextAttributes(
            fontSize: fontSize,
            style: style,
            lineBreakMode: .byClipping
        )

        while fontSize > style.minimumFontSize && !singleLineText(text, with: attributes, fits: rect.size) {
            fontSize -= 1
            attributes = fittedTextAttributes(
                fontSize: fontSize,
                style: style,
                lineBreakMode: .byClipping
            )
        }

        let measuredSize = (text as NSString).size(withAttributes: attributes)
        let drawRect = CGRect(
            x: rect.minX,
            y: rect.minY + max(0, (rect.height - measuredSize.height) / 2),
            width: rect.width,
            height: min(rect.height, ceil(measuredSize.height))
        )
        (text as NSString).draw(in: drawRect, withAttributes: attributes)
    }

    private static func drawWrappedText(
        _ text: String,
        in rect: CGRect,
        style: ShareTextStyle,
        maximumLines: Int
    ) {
        var fontSize = style.maximumFontSize
        var attributes = wrappedTextAttributes(
            fontSize: fontSize,
            style: style
        )
        var measuredHeight = wrappedTextHeight(text, width: rect.width, attributes: attributes)
        var maximumHeight = maximumWrappedHeight(fontSize: fontSize, weight: style.weight, maximumLines: maximumLines)

        while fontSize > style.minimumFontSize && measuredHeight > min(rect.height, maximumHeight) {
            fontSize -= 1
            attributes = wrappedTextAttributes(
                fontSize: fontSize,
                style: style
            )
            measuredHeight = wrappedTextHeight(text, width: rect.width, attributes: attributes)
            maximumHeight = maximumWrappedHeight(
                fontSize: fontSize,
                weight: style.weight,
                maximumLines: maximumLines
            )
        }

        let drawHeight = min(rect.height, maximumHeight)
        let drawRect = CGRect(
            x: rect.minX,
            y: rect.minY + max(0, (rect.height - min(measuredHeight, drawHeight)) / 2),
            width: rect.width,
            height: drawHeight
        )
        (text as NSString).draw(in: drawRect, withAttributes: attributes)
    }

    private static func fittedTextAttributes(
        fontSize: CGFloat,
        style: ShareTextStyle,
        lineBreakMode: NSLineBreakMode
    ) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = style.alignment
        paragraph.lineBreakMode = lineBreakMode
        return [
            .font: UIFont.systemFont(ofSize: fontSize, weight: style.weight),
            .foregroundColor: style.color,
            .kern: style.letterSpacing,
            .paragraphStyle: paragraph
        ]
    }

    private static func wrappedTextAttributes(
        fontSize: CGFloat,
        style: ShareTextStyle
    ) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = style.alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 4
        return [
            .font: UIFont.systemFont(ofSize: fontSize, weight: style.weight),
            .foregroundColor: style.color,
            .paragraphStyle: paragraph
        ]
    }

    private static func singleLineText(
        _ text: String,
        with attributes: [NSAttributedString.Key: Any],
        fits size: CGSize
    ) -> Bool {
        let measuredSize = (text as NSString).size(withAttributes: attributes)
        return measuredSize.width <= size.width && measuredSize.height <= size.height
    }

    private static func wrappedTextHeight(
        _ text: String,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(bounds.height)
    }

    private static func maximumWrappedHeight(
        fontSize: CGFloat,
        weight: UIFont.Weight,
        maximumLines: Int
    ) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        return ceil(font.lineHeight * CGFloat(maximumLines) + 4 * CGFloat(max(0, maximumLines - 1)))
    }

    private static func recentHeatmapDays(
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<28).compactMap { offset in
            calendar.date(byAdding: .day, value: -(27 - offset), to: today)
        }
    }

    private static func writeImage(
        _ image: UIImage,
        named filename: String
    ) throws -> URL {
        let fileURL = try temporaryURL(named: filename)
        guard let data = image.pngData() else {
            throw SunclubShareArtifactError.encodingFailed
        }
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func temporaryURL(named filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sunclub-share-artifacts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(filename, isDirectory: false)
    }
}

enum SunclubShareArtifactError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Sunclub could not create that share artifact."
        }
    }
}
