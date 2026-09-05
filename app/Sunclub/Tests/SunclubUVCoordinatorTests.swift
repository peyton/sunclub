import Foundation
import XCTest
@testable import Sunclub

@MainActor
final class SunclubUVCoordinatorTests: XCTestCase {
    func testSupersededForecastCannotPublishOverTheCurrentRequest() async {
        let coordinator = makeCoordinator()
        let input = SunclubUVCoordinator.Input(usesLiveUV: false, selectedPlace: nil)
        let superseded = coordinator.refreshForecast(input)
        let current = coordinator.refreshForecast(input)
        let acceptedSuperseded = await superseded.value
        let acceptedCurrent = await current.value
        XCTAssertFalse(acceptedSuperseded)
        XCTAssertTrue(acceptedCurrent)
        XCTAssertNotNil(coordinator.forecast)
    }

    func testChangedPreferenceDiscardsResponseWithoutPublishingForecast() async {
        let coordinator = makeCoordinator()
        let response = coordinator.refreshForecast(
            .init(usesLiveUV: false, selectedPlace: nil), acceptsResponse: { false }
        )
        let accepted = await response.value
        XCTAssertFalse(accepted)
        XCTAssertNil(coordinator.forecast)
        XCTAssertNil(coordinator.reading)
    }

    private func makeCoordinator() -> SunclubUVCoordinator {
        SunclubUVCoordinator(indexService: UVIndexService(), briefingService: SunclubUVBriefingService(),
                             clock: { Date(timeIntervalSince1970: 1_700_000_000) })
    }
}
