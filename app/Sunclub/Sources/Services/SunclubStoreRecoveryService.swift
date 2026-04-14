import CryptoKit
import Foundation
import SwiftData

struct SunclubStoreRecoveryResult: Equatable {
    let importSessionID: UUID
    let recoveredRecordCount: Int
    let sourceDescription: String
}

struct SunclubStoreRecoveryService {
    static let sourceDescriptionPrefix = "Legacy app-support store recovery"

    private let fileManager: FileManager
    private let storeLocationProvider: () throws -> SunclubStoreLocation

    init(
        storeLocation: SunclubStoreLocation? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let storeLocation {
            storeLocationProvider = { storeLocation }
        } else {
            storeLocationProvider = {
                try SunclubModelContainerFactory.sharedStoreLocation(fileManager: fileManager)
            }
        }
    }

    @MainActor
    func recoverLegacyApplicationSupportStoreIfNeeded(
        into context: ModelContext,
        historyService: SunclubHistoryService
    ) throws -> SunclubStoreRecoveryResult? {
        _ = context
        let storeLocation = try storeLocationProvider()
        let currentStoreURL = storeLocation.currentStoreURL.standardizedFileURL
        let legacyStoreURL = storeLocation.legacyApplicationSupportStoreURL.standardizedFileURL
        guard storeLocation.isUsingAppGroupContainer,
              currentStoreURL != legacyStoreURL else {
            return nil
        }

        let storeFiles: [SunclubBackupStoreFile]
        do {
            storeFiles = try SunclubBackupService.storeFiles(
                at: storeLocation.legacyApplicationSupportStoreURL,
                fileManager: fileManager
            )
        } catch SunclubBackupError.missingStoreFiles {
            return nil
        }

        let fingerprint = Self.fingerprint(for: storeFiles)
        let sourceDescription = "\(Self.sourceDescriptionPrefix): \(fingerprint)"
        guard try historyService.hasImportSession(sourceDescriptionPrefix: sourceDescription) == false else {
            return nil
        }

        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let copiedStoreURL = temporaryDirectory.appendingPathComponent(
            SunclubModelContainerFactory.sharedStoreFilename,
            isDirectory: false
        )
        try writeStoreFiles(storeFiles, toStoreAt: copiedStoreURL)

        let importedContainer = try SunclubModelContainerFactory.makeDiskBackedContainer(url: copiedStoreURL)
        let importedContext = ModelContext(importedContainer)
        let importedHistoryService = SunclubHistoryService(context: importedContext)
        try importedHistoryService.refreshProjectedState()
        let importedRecordCount = try importedHistoryService.records().count

        guard let importResult = try historyService.recoverLegacyDomainData(
            from: importedContext,
            sourceDescription: sourceDescription
        ) else {
            return nil
        }

        return SunclubStoreRecoveryResult(
            importSessionID: importResult.importSessionID,
            recoveredRecordCount: importedRecordCount,
            sourceDescription: sourceDescription
        )
    }

    private static func fingerprint(for storeFiles: [SunclubBackupStoreFile]) -> String {
        var digestInput = Data()
        for storeFile in storeFiles.sorted(by: { $0.filename < $1.filename }) {
            digestInput.append(Data(storeFile.filename.utf8))
            digestInput.append(0)
            digestInput.append(storeFile.data)
            digestInput.append(0)
        }

        return SHA256.hash(data: digestInput)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func writeStoreFiles(
        _ storeFiles: [SunclubBackupStoreFile],
        toStoreAt storeURL: URL
    ) throws {
        let directoryURL = storeURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        for storeFile in storeFiles {
            guard isValid(storeFilename: storeFile.filename) else {
                throw SunclubBackupError.invalidStoreFilename
            }

            let destinationURL = directoryURL.appendingPathComponent(
                storeFile.filename,
                isDirectory: false
            )
            try storeFile.data.write(to: destinationURL, options: .atomic)
        }
    }

    private func isValid(storeFilename: String) -> Bool {
        !storeFilename.isEmpty && storeFilename == URL(fileURLWithPath: storeFilename).lastPathComponent
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
