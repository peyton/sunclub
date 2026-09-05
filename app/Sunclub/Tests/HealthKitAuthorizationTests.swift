import HealthKit
import XCTest
@testable import Sunclub

@MainActor
final class HealthKitAuthorizationTests: XCTestCase {
    func testCompletedPromptDoesNotEnableDeniedWriteAccess() async {
        let granted = await SunclubHealthKitService.requestWriteAuthorization(
            request: {}, status: { .sharingDenied }
        )
        XCTAssertFalse(granted)
    }

    func testCompletedPromptDoesNotEnableUndeterminedWriteAccess() async {
        let granted = await SunclubHealthKitService.requestWriteAuthorization(
            request: {}, status: { .notDetermined }
        )
        XCTAssertFalse(granted)
    }

    func testGrantedWriteAccessEnablesHealth() async {
        let granted = await SunclubHealthKitService.requestWriteAuthorization(
            request: {}, status: { .sharingAuthorized }
        )
        XCTAssertTrue(granted)
    }

    func testPromptFailureDoesNotEnableHealth() async {
        let granted = await SunclubHealthKitService.requestWriteAuthorization(
            request: { throw CancellationError() }, status: { .sharingAuthorized }
        )
        XCTAssertFalse(granted)
    }
}
