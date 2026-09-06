import CoreLocation
import Foundation

enum LeaveHomeAuthorizationState: Equatable {
    case notDetermined
    case whenInUse
    case always
    case denied
    case restricted
    case unknown

    init(status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .authorizedWhenInUse:
            self = .whenInUse
        case .authorizedAlways:
            self = .always
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .unknown
        }
    }
}

@MainActor
protocol HomeExitReminderMonitoring: AnyObject {
    var authorizationState: LeaveHomeAuthorizationState { get }

    func setStateProvider(_ provider: @escaping () -> (any SunclubReminderState)?)
    func refreshMonitoring(using state: any SunclubReminderState, allowPermissionPrompt: Bool) async -> LeaveHomeAuthorizationState
    func saveHomeFromCurrentLocation() async throws -> HomeLocation
    func hasTriggeredReminder(on date: Date) -> Bool
}

@MainActor
final class NoopHomeExitReminderMonitor: HomeExitReminderMonitoring {
    var authorizationState: LeaveHomeAuthorizationState = .notDetermined

    func setStateProvider(_ provider: @escaping () -> (any SunclubReminderState)?) {}

    func refreshMonitoring(using state: any SunclubReminderState, allowPermissionPrompt: Bool) async -> LeaveHomeAuthorizationState {
        authorizationState
    }

    func saveHomeFromCurrentLocation() async throws -> HomeLocation {
        throw SharedLocationError.locationUnavailable
    }

    func hasTriggeredReminder(on date: Date) -> Bool {
        false
    }
}

@MainActor
final class HomeExitReminderMonitor: HomeExitReminderMonitoring {
    static let shared = HomeExitReminderMonitor()
    nonisolated static let regionIdentifier = "sunclub.leave-home.home"

    private let locationService: SharedLocationManaging
    private let notificationManager: NotificationScheduling
    private let stateStore: HomeExitReminderStateStoring
    private let calendar: Calendar
    private let currentDate: () -> Date
    private var stateProvider: (() -> (any SunclubReminderState)?)?
    private var isHandlingExit = false

    init(
        locationService: SharedLocationManaging? = nil,
        notificationManager: NotificationScheduling? = nil,
        stateStore: HomeExitReminderStateStoring? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        clock: @escaping () -> Date = Date.init
    ) {
        self.locationService = locationService ?? SharedLocationManager.shared
        self.notificationManager = notificationManager ?? NotificationManager.shared
        self.stateStore = stateStore ?? HomeExitReminderStateStore()
        self.calendar = calendar
        currentDate = clock
        self.locationService.eventHandler = { [weak self] event in
            Task { @MainActor in
                await self?.handle(event)
            }
        }
    }

    var authorizationState: LeaveHomeAuthorizationState {
        LeaveHomeAuthorizationState(status: locationService.authorizationStatus)
    }

    func setStateProvider(_ provider: @escaping () -> (any SunclubReminderState)?) {
        stateProvider = provider
    }

    func refreshMonitoring(using state: any SunclubReminderState, allowPermissionPrompt: Bool) async -> LeaveHomeAuthorizationState {
        let leaveHomeSettings = state.settings.smartReminderSettings.leaveHomeReminder

        guard leaveHomeSettings.isEnabled,
              let homeLocation = leaveHomeSettings.homeLocation else {
            locationService.stopMonitoring(regionIdentifier: Self.regionIdentifier)
            stateStore.clearObservedInsideDay()
            return authorizationState
        }

        let rawStatus = if allowPermissionPrompt {
            await locationService.requestAlwaysAuthorizationIfNeeded()
        } else {
            locationService.authorizationStatus
        }
        let mappedState = LeaveHomeAuthorizationState(status: rawStatus)

        guard mappedState == .always else {
            locationService.stopMonitoring(regionIdentifier: Self.regionIdentifier)
            stateStore.clearObservedInsideDay()
            return mappedState
        }

        await retryPendingDeparture(using: state)

        let region = CLCircularRegion(
            center: homeLocation.coordinate,
            radius: leaveHomeSettings.radiusMeters,
            identifier: Self.regionIdentifier
        )

        if let monitoredRegion = locationService.monitoredRegion(withIdentifier: Self.regionIdentifier),
           regionsMatch(monitoredRegion, region) {
            locationService.requestState(for: monitoredRegion)
            return mappedState
        }

        if locationService.monitoredRegion(withIdentifier: Self.regionIdentifier) != nil {
            stateStore.clearObservedInsideDay()
        }
        locationService.stopMonitoring(regionIdentifier: Self.regionIdentifier)
        locationService.startMonitoring(region: region)
        locationService.requestState(for: region)
        return mappedState
    }

    func saveHomeFromCurrentLocation() async throws -> HomeLocation {
        let status = await locationService.requestWhenInUseAuthorizationIfNeeded()
        switch status {
        case .denied, .restricted:
            throw SharedLocationError.permissionDenied
        default:
            break
        }

        let location = try await locationService.currentLocation()
        stateStore.clearObservedInsideDay()
        return HomeLocation(coordinate: location.coordinate)
    }

    func hasTriggeredReminder(on date: Date) -> Bool {
        stateStore.hasFired(on: date, calendar: calendar)
    }

    private func handle(_ event: SharedLocationEvent) async {
        guard let state = stateProvider?(),
              state.settings.smartReminderSettings.leaveHomeReminder.homeLocation != nil else {
            return
        }

        switch event {
        case let .authorizationChanged(status):
            let mappedState = LeaveHomeAuthorizationState(status: status)
            guard mappedState != .always || state.settings.smartReminderSettings.leaveHomeReminder.isEnabled else {
                return
            }
            _ = await refreshMonitoring(using: state, allowPermissionPrompt: false)
        case let .didDetermineState(regionState, region):
            guard region.identifier == Self.regionIdentifier else { return }
            switch regionState {
            case .inside:
                stateStore.markObservedInside(on: currentDate(), calendar: calendar)
            case .outside:
                await handlePotentialExit(using: state, now: currentDate())
            case .unknown:
                break
            @unknown default:
                break
            }
        case let .didEnterRegion(region):
            guard region.identifier == Self.regionIdentifier else { return }
            stateStore.markObservedInside(on: currentDate(), calendar: calendar)
        case let .didExitRegion(region):
            guard region.identifier == Self.regionIdentifier else { return }
            await handlePotentialExit(using: state, now: currentDate())
        }
    }

    private func handlePotentialExit(using state: any SunclubReminderState, now: Date) async {
        guard !isHandlingExit else { return }
        isHandlingExit = true
        defer { isHandlingExit = false }
        guard stateStore.hasObservedInside(on: now, calendar: calendar) else { return }
        stateStore.clearObservedInsideDay()
        let leaveHomeSettings = state.settings.smartReminderSettings.leaveHomeReminder
        guard leaveHomeSettings.isEnabled,
              leaveHomeSettings.homeLocation != nil,
              authorizationState == .always,
              !stateStore.hasFired(on: now, calendar: calendar),
              state.record(for: now) == nil else {
            return
        }

        guard (6..<20).contains(calendar.component(.hour, from: now)) else { return }
        let checkInID: UUID
        do {
            guard let savedID = try state.recordDepartureCheckIn(at: now) else { return }
            checkInID = savedID
        } catch {
            // A failed save must never publish a prompt for nonexistent history.
            return
        }
        let result = await notificationManager.scheduleDepartureCheckIn(id: checkInID, at: now)
        guard result.isSuccessful else {
            return
        }
        stateStore.markFired(on: now, calendar: calendar)
        stateStore.clearObservedInsideDay()
    }

    private func retryPendingDeparture(using state: any SunclubReminderState) async {
        let now = currentDate()
        guard !isHandlingExit, (6..<20).contains(calendar.component(.hour, from: now)),
              !stateStore.hasFired(on: now, calendar: calendar),
              let pending = state.pendingDepartureReminder,
              pending.snoozedUntil == nil, pending.isActive(at: now, calendar: calendar) else { return }
        isHandlingExit = true
        defer { isHandlingExit = false }
        let result = await notificationManager.scheduleDepartureCheckIn(id: pending.id, at: now)
        if result.isSuccessful { stateStore.markFired(on: now, calendar: calendar) }
    }

    private func regionsMatch(_ lhs: CLCircularRegion, _ rhs: CLCircularRegion) -> Bool {
        abs(lhs.center.latitude - rhs.center.latitude) < 0.000_001
            && abs(lhs.center.longitude - rhs.center.longitude) < 0.000_001
            && abs(lhs.radius - rhs.radius) < 1
    }
}
