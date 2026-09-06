import Foundation

/// Status text and actions are derived from snapshots without triggering permissions or network requests.
enum SunclubStatusPresentation {
    static func leaveHomeReminderStatusPresentation(
        reminderSettings: SmartReminderSettings,
        leaveHomeAuthorizationState: LeaveHomeAuthorizationState,
        leaveHomeReminderErrorMessage: String?
    ) -> LeaveHomeReminderStatusPresentation {
        let leaveHomeReminder = reminderSettings.leaveHomeReminder

        if leaveHomeReminder.homeLocation == nil {
            switch leaveHomeAuthorizationState {
            case .denied, .restricted:
                return LeaveHomeReminderStatusPresentation(
                    title: "Location access is off",
                    detail: "Open Settings so Sunclub can save your current location as Home.",
                    symbol: "location.slash",
                    tone: .warning,
                    actionTitle: "Open Settings",
                    actionKind: .openSettings
                )
            default:
                return LeaveHomeReminderStatusPresentation(
                    title: "Home isn't set",
                    detail: leaveHomeReminderErrorMessage
                        ?? "Save your current location and Sunclub can remind you when you head out.",
                    symbol: "house",
                    tone: .neutral,
                    actionTitle: "Use Current Location as Home",
                    actionKind: .setHomeFromCurrentLocation
                )
            }
        }

        guard leaveHomeReminder.isEnabled else {
            return LeaveHomeReminderStatusPresentation(
                title: "Home is saved",
                detail: "Turn this on to use your first trip out as the morning reminder.",
                symbol: "house.fill",
                tone: .neutral,
                actionTitle: nil,
                actionKind: nil
            )
        }

        switch leaveHomeAuthorizationState {
        case .always:
            return LeaveHomeReminderStatusPresentation(
                title: "First exit reminder is ready",
                detail: "Sunclub will watch Home with a \(Int(leaveHomeReminder.radiusMeters)) m radius and send one reminder before your usual weekday or weekend time if today is still open.",
                symbol: "figure.walk.departure",
                tone: .success,
                actionTitle: nil,
                actionKind: nil
            )
        case .notDetermined, .whenInUse, .unknown:
            return LeaveHomeReminderStatusPresentation(
                title: "Background location needed",
                detail: "Allow Always location so Sunclub can catch your first exit even when the app isn't open.",
                symbol: "location.fill",
                tone: .warning,
                actionTitle: "Allow Background Access",
                actionKind: .requestAlwaysAuthorization
            )
        case .denied, .restricted:
            return LeaveHomeReminderStatusPresentation(
                title: "Location access is off",
                detail: "Open Settings to re-enable Always location access for this reminder.",
                symbol: "location.slash",
                tone: .warning,
                actionTitle: "Open Settings",
                actionKind: .openSettings
            )
        }
    }

    static func liveUVStatusPresentation(
        uvStatus: SunclubUVStatus, uvReading: UVReading?, uvForecast: SunclubUVForecast?,
        canRefresh: Bool, liveUVAccessState: LiveUVAccessState
    ) -> LiveUVStatusPresentation {
        if uvStatus.availability == .available, let updatedAt = uvStatus.updatedAt {
            let sourceLabel = uvReading?.source.statusLabel
                ?? uvForecast?.sourceLabel
                ?? UVReadingSource.localEstimate.statusLabel
            let locationLabel = uvStatus.source?.displayName(for: uvReading?.source)
            let updatedLabel = updatedAt.formatted(date: .omitted, time: .shortened)

            switch uvStatus.freshness {
            case .fresh:
                let locationDetail = locationLabel.map { " · \($0)" } ?? ""
                return LiveUVStatusPresentation(
                    title: "UV available",
                    detail: "\(sourceLabel)\(locationDetail) · Updated \(updatedLabel).",
                    actionTitle: canRefresh ? "Refresh" : nil,
                    actionKind: canRefresh ? .refresh : nil
                )
            case .stale:
                let locationDetail = locationLabel.map { " for \($0)" } ?? ""
                return LiveUVStatusPresentation(
                    title: "Cached UV available",
                    detail: "\(sourceLabel)\(locationDetail) · Last updated \(updatedLabel). Sunclub will refresh when the request budget allows.",
                    actionTitle: canRefresh ? "Refresh" : nil,
                    actionKind: canRefresh ? .refresh : nil
                )
            case .estimated:
                let basis = locationLabel.map { " for \($0)" } ?? " from season and time of day"
                return LiveUVStatusPresentation(
                    title: "Estimated UV available",
                    detail: "\(sourceLabel)\(basis) · Updated \(updatedLabel). Apple Weather will replace it when available.",
                    actionTitle: canRefresh ? "Refresh" : nil,
                    actionKind: canRefresh ? .refresh : nil
                )
            case .unavailable:
                break
            }
        }

        switch liveUVAccessState {
        case .live, .unavailable:
            return LiveUVStatusPresentation(
                title: "UV unavailable",
                detail: "Sunclub could not resolve a cached value or local estimate.",
                actionTitle: "Retry",
                actionKind: .refresh
            )
        case .denied:
            return LiveUVStatusPresentation(
                title: "UV unavailable",
                detail: "Location permission is denied. Enable it or choose a city for Apple Weather UV.",
                actionTitle: "Open Settings",
                actionKind: .openSettings
            )
        case .needsPermission:
            return LiveUVStatusPresentation(
                title: "Enable Live UV",
                detail: "Allow location access to pull UV from Apple Weather.",
                actionTitle: "Allow Location",
                actionKind: .requestPermission
            )
        case .disabled:
            return LiveUVStatusPresentation(
                title: "UV unavailable",
                detail: "Enable live location or choose a city to get verified Apple Weather UV.",
                actionTitle: nil,
                actionKind: nil
            )
        }
    }

    static func cloudSyncStatusPresentation(
        pendingImportedBatchCount: Int, status: CloudSyncStatus, lastSyncAt: Date?, lastSyncError: String?
    ) -> CloudSyncStatusPresentation {

        switch status {
        case .paused:
            return CloudSyncStatusPresentation(
                title: "Saved only on this phone",
                detail: "Turn iCloud sync back on to keep your history in sync.",
                actionTitle: "Turn On iCloud Sync",
                pendingImportedBatchCount: pendingImportedBatchCount
            )
        case .syncing:
            return CloudSyncStatusPresentation(
                title: "Syncing with iCloud",
                detail: "Sending recent changes and checking your other devices.",
                actionTitle: nil,
                pendingImportedBatchCount: pendingImportedBatchCount
            )
        case .error:
            return CloudSyncStatusPresentation(
                title: "iCloud needs attention",
                detail: lastSyncError ?? "Sunclub couldn't finish the last sync.",
                actionTitle: "Try Again",
                pendingImportedBatchCount: pendingImportedBatchCount
            )
        case .idle:
            let detail: String
            if let lastSyncAt {
                detail = "Last synced \(lastSyncAt.formatted(date: .abbreviated, time: .shortened))."
            } else {
                detail = "Your history is syncing with iCloud."
            }

            return CloudSyncStatusPresentation(
                title: "iCloud sync is on",
                detail: detail,
                actionTitle: "Sync Now",
                pendingImportedBatchCount: pendingImportedBatchCount
            )
        }
    }

}
