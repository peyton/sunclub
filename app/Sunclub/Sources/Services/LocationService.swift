import CoreLocation
import Foundation

enum SharedLocationEvent {
    case authorizationChanged(CLAuthorizationStatus)
    case didDetermineState(CLRegionState, CLRegion)
    case didEnterRegion(CLRegion)
    case didExitRegion(CLRegion)
}

enum SharedLocationError: LocalizedError {
    case locationUnavailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Sunclub could not determine your current location."
        case .permissionDenied:
            return "Location access is required for this action."
        }
    }
}

@MainActor
protocol SharedLocationManaging: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var eventHandler: ((SharedLocationEvent) -> Void)? { get set }

    func requestWhenInUseAuthorizationIfNeeded() async -> CLAuthorizationStatus
    func requestAlwaysAuthorizationIfNeeded() async -> CLAuthorizationStatus
    func currentLocation() async throws -> CLLocation
    func monitoredRegion(withIdentifier identifier: String) -> CLCircularRegion?
    func startMonitoring(region: CLCircularRegion)
    func stopMonitoring(regionIdentifier: String)
    func requestState(for region: CLRegion)
}

@MainActor
final class SharedLocationManager: NSObject, SharedLocationManaging, @preconcurrency CLLocationManagerDelegate {
    static let shared = SharedLocationManager()

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    var eventHandler: ((SharedLocationEvent) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestWhenInUseAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        guard CLLocationManager.locationServicesEnabled() else {
            return .restricted
        }

        let status = manager.authorizationStatus
        guard status == .notDetermined else {
            return status
        }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        guard CLLocationManager.locationServicesEnabled() else {
            return .restricted
        }

        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .denied, .restricted:
            return status
        case .authorizedWhenInUse, .notDetermined:
            return await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestAlwaysAuthorization()
            }
        @unknown default:
            return status
        }
    }

    func currentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw SharedLocationError.locationUnavailable
        }

        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw SharedLocationError.permissionDenied
        default:
            break
        }

        if let location = manager.location,
           abs(location.timestamp.timeIntervalSinceNow) < 1_800 {
            return location
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func monitoredRegion(withIdentifier identifier: String) -> CLCircularRegion? {
        manager.monitoredRegions
            .first(where: { $0.identifier == identifier }) as? CLCircularRegion
    }

    func startMonitoring(region: CLCircularRegion) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            return
        }

        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
    }

    func stopMonitoring(regionIdentifier: String) {
        guard let region = manager.monitoredRegions.first(where: { $0.identifier == regionIdentifier }) else {
            return
        }

        manager.stopMonitoring(for: region)
    }

    func requestState(for region: CLRegion) {
        manager.requestState(for: region)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationContinuation?.resume(returning: manager.authorizationStatus)
        authorizationContinuation = nil
        eventHandler?(.authorizationChanged(manager.authorizationStatus))
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        eventHandler?(.didDetermineState(state, region))
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        eventHandler?(.didEnterRegion(region))
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        eventHandler?(.didExitRegion(region))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationContinuation?.resume(throwing: SharedLocationError.locationUnavailable)
            locationContinuation = nil
            return
        }

        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}

extension HomeLocation {
    init(coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
