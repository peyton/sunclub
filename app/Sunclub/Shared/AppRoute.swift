import Foundation
import Observation

enum AppRoute: String, Hashable, Codable, Identifiable {
    case home
    case barcodeScan
    case selfie
    case videoVerify
    case training
    case calendar
    case weeklyReport

    var id: String { rawValue }
}

@Observable
final class AppRouter {
    var path: [AppRoute] = []

    func open(_ route: AppRoute) {
        if route == .home {
            path.removeAll()
        } else {
            path = [route]
        }
    }

    func goHome() {
        path.removeAll()
    }
}
