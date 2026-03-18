import Foundation

final class Fastfile: LaneFile {
    private let projectPath = "Sunclub.xcodeproj"
    private let scheme = "Sunclub"
    private let simulatorName = "iPhone 17 Pro"
    private let bundleIdentifier = "app.peyton.sunclub"
    private let buildRoot = "build/fastlane"
    private let archivePath = "build/fastlane/Sunclub.xcarchive"
    private let releaseOutputDirectory = "build/fastlane/release"
    private let releaseOutputName = "Sunclub.ipa"
    private let modelConfigPath = "Sunclub/FastVLMModel/model/config.json"
    private let modelDownloadCommand = "chmod +x ./get_pretrained_mlx_model.sh && ./get_pretrained_mlx_model.sh --model 0.5b --dest Sunclub/FastVLMModel/model"

    private func configuredString(_ value: String) -> OptionalConfigValue<String?> {
        .userDefined(value)
    }

    private func testCommand(onlyTesting target: String) -> String {
        """
        set -euo pipefail
        mkdir -p '\(buildRoot)'
        xcodebuild test \
          -project '\(projectPath)' \
          -scheme '\(scheme)' \
          -destination 'platform=iOS Simulator,name=\(simulatorName)' \
          -parallel-testing-enabled NO \
          -maximum-parallel-testing-workers 1 \
          -derivedDataPath '\(buildRoot)/derived-data' \
          '-only-testing:\(target)'
        """
    }

    func prepareModelLane() {
        desc("Ensure the FastVLM 0.5B model exists in the Xcode-synced model directory")

        guard !FileManager.default.fileExists(atPath: modelConfigPath) else { return }

        sh(command: modelDownloadCommand, log: true)
    }

    func unitTestsLane() {
        desc("Run the Sunclub unit test target")

        prepareModelLane()
        sh(command: testCommand(onlyTesting: "SunclubTests"), log: true)
    }

    func uiTestsLane() {
        desc("Run the Sunclub UI test target")

        prepareModelLane()
        sh(command: testCommand(onlyTesting: "SunclubUITests"), log: true)
    }

    func testsLane() {
        desc("Run unit and UI tests")

        unitTestsLane()
        uiTestsLane()
    }

    func buildLane() {
        desc("Prepare the FastVLM model and archive the app without codesigning for local validation")

        prepareModelLane()
        archiveWithoutCodesigning()
    }

    func betaLane() {
        desc("Archive the release build and upload it to TestFlight using App Store Connect API key auth")

        prepareModelLane()
        configureAppStoreConnectApiKey()

        let ipaPath = archiveReleaseIpa()
        uploadToTestflight(
            appIdentifier: configuredString(bundleIdentifier),
            ipa: configuredString(ipaPath),
            skipSubmission: true,
            skipWaitingForBuildProcessing: true
        )
    }

    func releaseLane() {
        desc("Archive the release build and upload it to App Store Connect using App Store Connect API key auth")

        prepareModelLane()
        configureAppStoreConnectApiKey()

        let ipaPath = archiveReleaseIpa()
        uploadToAppStore(
            appIdentifier: configuredString(bundleIdentifier),
            ipa: configuredString(ipaPath),
            skipScreenshots: true,
            skipMetadata: true,
            force: true,
            submitForReview: false,
        )
    }

    private func archiveWithoutCodesigning() {
        let command = """
        set -euo pipefail
        mkdir -p '\(buildRoot)'
        xcodebuild archive \
          -project '\(projectPath)' \
          -scheme '\(scheme)' \
          -destination 'generic/platform=iOS' \
          -archivePath '\(archivePath)' \
          CODE_SIGNING_ALLOWED=NO \
          CODE_SIGNING_REQUIRED=NO
        """

        sh(command: command, log: true)
    }

    @discardableResult
    private func archiveReleaseIpa() -> String {
        buildApp(
            project: configuredString(projectPath),
            scheme: configuredString(scheme),
            clean: true,
            outputDirectory: releaseOutputDirectory,
            outputName: configuredString(releaseOutputName),
            configuration: configuredString("Release"),
            exportMethod: configuredString("app-store"),
            buildPath: configuredString("\(buildRoot)/archives"),
            archivePath: configuredString(archivePath),
            destination: configuredString("generic/platform=iOS"),
            disableXcpretty: .userDefined(true),
            skipPackageDependenciesResolution: true
        )
    }

    private func configureAppStoreConnectApiKey() {
        guard let keyID = environmentValue(named: "APP_STORE_CONNECT_API_KEY_ID"), !keyID.isEmpty else {
            fatalError("Missing APP_STORE_CONNECT_API_KEY_ID")
        }

        let issuerID = environmentValue(named: "APP_STORE_CONNECT_API_ISSUER_ID")
        let keyPath = environmentValue(named: "APP_STORE_CONNECT_API_KEY_PATH")
        let keyContent = environmentValue(named: "APP_STORE_CONNECT_API_KEY_CONTENT")

        guard
            let credential = [keyPath, keyContent].first(where: { value in
                guard let value else { return false }
                return !value.isEmpty
            })
        else {
            fatalError("Set APP_STORE_CONNECT_API_KEY_PATH or APP_STORE_CONNECT_API_KEY_CONTENT before running beta or release.")
        }

        if credential == keyPath {
            appStoreConnectApiKey(
                keyId: keyID,
                issuerId: .fastlaneDefault(issuerID),
                keyFilepath: .fastlaneDefault(keyPath),
                setSpaceshipToken: true
            )
        } else {
            appStoreConnectApiKey(
                keyId: keyID,
                issuerId: .fastlaneDefault(issuerID),
                keyContent: .fastlaneDefault(keyContent),
                setSpaceshipToken: true
            )
        }
    }

    private func environmentValue(named key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
}
