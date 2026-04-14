import XCTest
@testable import Sunclub

final class PolishImprovementsTests: XCTestCase {
    func testSuccessBurstMilestoneThresholds() {
        XCTAssertEqual(SunSuccessBurst.milestoneLevel(for: 1), .standard)
        XCTAssertEqual(SunSuccessBurst.milestoneLevel(for: 6), .standard)
        XCTAssertEqual(SunSuccessBurst.milestoneLevel(for: 7), .minor)
        XCTAssertEqual(SunSuccessBurst.milestoneLevel(for: 29), .minor)
        XCTAssertEqual(SunSuccessBurst.milestoneLevel(for: 30), .major)
        XCTAssertEqual(SunSuccessBurst.milestoneLevel(for: 99), .major)
        XCTAssertEqual(SunSuccessBurst.milestoneLevel(for: 100), .major)
        XCTAssertEqual(SunSuccessBurst.milestoneLevel(for: 365), .epic)
    }

    func testSuccessCopyCatalogIsNotEmpty() {
        XCTAssertFalse(SunclubCopy.Phrases.success.isEmpty)
        XCTAssertGreaterThanOrEqual(SunclubCopy.Phrases.success.count, 8)
    }

    func testSuccessCopyRotationProducesNonEmptyPhrase() {
        let (phrase, state) = PhraseRotation.nextPhrase(from: nil, catalog: SunclubCopy.Phrases.success)
        XCTAssertFalse(phrase.isEmpty)
        XCTAssertFalse(state.isEmpty)
    }
}
