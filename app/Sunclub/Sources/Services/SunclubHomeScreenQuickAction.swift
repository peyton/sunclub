import UIKit

enum SunclubHomeScreenQuickAction: String {
    case logToday = "app.peyton.sunclub.log-today"

    var route: AppRoute {
        switch self {
        case .logToday:
            return .manualLog
        }
    }

    @discardableResult
    static func handleShortcutItem(
        _ shortcutItem: UIApplicationShortcutItem,
        routeStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore()
    ) -> Bool {
        handleShortcutType(shortcutItem.type, routeStore: routeStore)
    }

    @discardableResult
    static func handleShortcutType(
        _ type: String,
        routeStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore()
    ) -> Bool {
        guard let action = Self(rawValue: type) else {
            return false
        }

        routeStore.setPendingRoute(action.route)
        return true
    }
}
