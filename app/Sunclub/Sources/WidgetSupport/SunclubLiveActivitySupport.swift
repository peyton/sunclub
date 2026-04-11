import ActivityKit
import Foundation

struct SunclubLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentUVIndex: Int
        var peakUVIndex: Int
        var countdownLabel: String
        var lastAppliedLabel: String
        var streakLabel: String
    }

    var headline: String
}
