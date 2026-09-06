import SwiftUI

/// Bundled Lucide 0.468.0 SVGs, rendered as monochrome templates.
enum SunIcon: String, CaseIterable {
    case sun, calendar, settings, check, clock, plus, chevronLeft, chevronRight, chart, shield
    case cloud, bell, sparkles, book, lifeBuoy, circleHelp, mail
    // Upstream milk.svg supplies the capped bottle; heart-pulse.svg supplies Health.
    case sunscreen, heartPulse

    var assetName: String {
        "Quiet" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    var image: Image {
        Image(assetName).renderingMode(.template)
    }

    init(tab: AppTab) {
        switch tab {
        case .today: self = .sun
        case .history: self = .calendar
        case .settings: self = .settings
        }
    }
}
