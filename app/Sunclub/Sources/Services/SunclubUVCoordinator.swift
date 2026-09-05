import Foundation
import Observation

@MainActor
@Observable
final class SunclubUVCoordinator {
    struct Input {
        let usesLiveUV: Bool
        let selectedPlace: SunclubSelectedUVPlace?
        var allowPermissionPrompt = false
    }

    private let indexService: UVIndexService
    private let briefingService: SunclubUVBriefingService
    private let clock: () -> Date
    private let calendar: Calendar
    private var generation = 0
    private var readingOverride: UVReading?
    private(set) var reading: UVReading?
    var forecast: SunclubUVForecast?
    private(set) var status: SunclubUVStatus = .unavailable
    private(set) var protectionWindow: SunclubUVProtectionWindow?

    init(indexService: UVIndexService, briefingService: SunclubUVBriefingService,
         calendar: Calendar = .current, clock: @escaping () -> Date) {
        self.indexService = indexService
        self.briefingService = briefingService
        self.calendar = calendar
        self.clock = clock
    }

    /// Each refresh owns immutable inputs; stale responses cannot replace a newer request.
    func refreshForecast(_ input: Input, acceptsResponse: @escaping () -> Bool = { true }) -> Task<Bool, Never> {
        generation += 1
        let requestGeneration = generation
        let now = clock()
        return Task {
            if input.usesLiveUV || readingOverride == nil {
                await fetchReading(input, now: now)
            }
            let resolvedReading = readingOverride ?? indexService.currentReading
            let resolvedForecast = await briefingService.forecast(
                prefersLiveData: input.usesLiveUV, liveBundle: indexService.lastBundle,
                readingSource: resolvedReading?.source, fallbackLatitude: indexService.fallbackLatitude,
                allowPermissionPrompt: input.allowPermissionPrompt, referenceDate: now, calendar: calendar
            )
            guard generation == requestGeneration, acceptsResponse() else { return false }
            reading = resolvedReading
            forecast = resolvedForecast
            status = indexService.status
            protectionWindow = indexService.protectionWindow
            return true
        }
    }

    func refreshReading(_ input: Input) async -> Bool {
        if let readingOverride {
            reading = readingOverride
            return false
        }
        let requestGeneration = generation
        await fetchReading(input, now: clock())
        guard readingOverride == nil, generation == requestGeneration else { return false }
        reading = indexService.currentReading
        status = indexService.status
        protectionWindow = indexService.protectionWindow
        return true
    }

    func overrideReading(_ value: UVReading?) {
        readingOverride = value
        reading = value
        if let value {
            status = SunclubUVStatus(availability: .available, source: .liveLocation,
                                     freshness: .fresh, updatedAt: value.timestamp)
        } else {
            status = .unavailable
            protectionWindow = nil
        }
    }

    private func fetchReading(_ input: Input, now: Date) async {
        await indexService.fetchUVIndex(
            prefersLiveData: input.usesLiveUV, selectedPlace: input.selectedPlace,
            allowPermissionPrompt: input.allowPermissionPrompt, now: now
        )
    }
}
