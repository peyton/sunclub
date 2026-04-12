import SwiftUI
import WidgetKit

@main
struct SunclubWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SunclubLogTodayWidget()
        SunclubStreakWidget()
        SunclubStatsWidget()
        SunclubCalendarWidget()
        SunclubAccountabilityWidget()
        SunclubLogTodayControl()
        SunclubSummaryControl()
        SunclubHistoryControl()
        SunclubLiveActivityWidget()
    }
}
