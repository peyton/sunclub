import UIKit
import XCTest
@testable import Sunclub

@MainActor
final class ShareArtifactTests: XCTestCase {
    func testAchievementShareCardRendersUnlocked7DayShield() throws {
        let achievement = SunclubAchievement(
            id: .streak7,
            title: SunclubAchievementID.streak7.title,
            detail: "Your longest streak reached 13 days.",
            symbolName: SunclubAchievementID.streak7.symbolName,
            currentValue: 13,
            targetValue: SunclubAchievementID.streak7.targetValue,
            isUnlocked: true,
            shareBlurb: "I unlocked 7-Day Shield in Sunclub."
        )

        let artifact = try SunclubShareArtifactService.makeAchievementCard(
            achievement: achievement,
            seasonStyle: .summerGlow
        )
        let image = try XCTUnwrap(UIImage(contentsOfFile: artifact.fileURL.path))

        XCTAssertTrue(FileManager.default.fileExists(atPath: artifact.fileURL.path))
        XCTAssertEqual(artifact.fileURL.pathExtension, "png")
        XCTAssertEqual(image.size.width, 1080, accuracy: 0.1)
        XCTAssertEqual(image.size.height, 1350, accuracy: 0.1)
        XCTAssertEqual(SunclubShareArtifactService.appLinkDisplay, "sunclub.peyton.app")
        XCTAssertEqual(
            artifact.shareText,
            "I unlocked 7-Day Shield in Sunclub. Build your sunscreen streak: sunclub.peyton.app"
        )
        XCTAssertFalse(try XCTUnwrap(artifact.shareText).contains("https://"))
    }

    func testAchievementShareCardsRenderForEveryAchievementTitle() throws {
        for (index, id) in SunclubAchievementID.allCases.enumerated() {
            let achievement = SunclubAchievement(
                id: id,
                title: id.title,
                detail: unlockedDetail(for: id, currentValue: id.targetValue + index),
                symbolName: id.symbolName,
                currentValue: id.targetValue + index,
                targetValue: id.targetValue,
                isUnlocked: true,
                shareBlurb: "I unlocked \(id.title) in Sunclub."
            )
            let style: SunclubSeasonStyle = index.isMultiple(of: 2) ? .summerGlow : .winterShield

            let artifact = try SunclubShareArtifactService.makeAchievementCard(
                achievement: achievement,
                seasonStyle: style
            )
            let image = try XCTUnwrap(UIImage(contentsOfFile: artifact.fileURL.path))

            XCTAssertEqual(image.size.width, 1080, accuracy: 0.1)
            XCTAssertEqual(image.size.height, 1350, accuracy: 0.1)
            XCTAssertTrue(artifact.shareText?.contains(SunclubShareArtifactService.appLinkDisplay) == true)
            XCTAssertFalse(artifact.shareText?.contains(SunclubShareArtifactService.appShareURLString) == true)
        }
    }

    private func unlockedDetail(
        for id: SunclubAchievementID,
        currentValue: Int
    ) -> String {
        switch id {
        case .streak7, .streak30, .streak100, .streak365:
            return "Your longest streak reached \(currentValue) days."
        case .firstReapply:
            return "You logged your first reapply check-in."
        case .firstBackfill:
            return "You repaired your history with a backfill."
        case .summerSurvivor:
            return "You stayed protected through \(currentValue) summer days."
        case .winterWarrior:
            return "You kept winter protection going for \(currentValue) days."
        }
    }
}
