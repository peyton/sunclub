import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SunclubBackupStoreFile: Codable, Equatable {
    let filename: String
    let data: Data
}

struct SunclubBackupPayload: Codable, Equatable {
    static let formatIdentifier = "sunclub-backup"
    static let currentFormatVersion = 1

    let formatIdentifier: String
    let formatVersion: Int
    let createdAt: Date
    let schemaVersion: String
    let storeFiles: [SunclubBackupStoreFile]

    init(
        createdAt: Date,
        schemaVersion: String,
        storeFiles: [SunclubBackupStoreFile]
    ) {
        self.formatIdentifier = Self.formatIdentifier
        self.formatVersion = Self.currentFormatVersion
        self.createdAt = createdAt
        self.schemaVersion = schemaVersion
        self.storeFiles = storeFiles
    }

    func validated() throws -> SunclubBackupPayload {
        guard formatIdentifier == Self.formatIdentifier else {
            throw SunclubBackupError.invalidBackupFile
        }
        guard formatVersion == Self.currentFormatVersion else {
            throw SunclubBackupError.unsupportedBackupVersion
        }
        guard !storeFiles.isEmpty else {
            throw SunclubBackupError.missingStoreFiles
        }
        guard storeFiles.contains(where: { $0.filename == SunclubBackupService.storeFilename }) else {
            throw SunclubBackupError.missingStoreFiles
        }
        return self
    }
}

struct SunclubBackupDocument: FileDocument {
    static let contentType = UTType(exportedAs: "app.peyton.sunclub.backup", conformingTo: .json)
    static let readableContentTypes: [UTType] = [contentType, .json]

    let payload: SunclubBackupPayload

    init(payload: SunclubBackupPayload) {
        self.payload = payload
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw SunclubBackupError.invalidBackupFile
        }
        self = try Self(data: data)
    }

    init(data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        payload = try decoder.decode(SunclubBackupPayload.self, from: data).validated()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try serializedData())
    }

    func serializedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    var suggestedFilename: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStamp = formatter.string(from: payload.createdAt)
        return "Sunclub-backup-\(dateStamp).json"
    }
}

enum SunclubBackupError: LocalizedError {
    case invalidBackupFile
    case unsupportedBackupVersion
    case missingStoreFiles
    case invalidStoreFilename

    var errorDescription: String? {
        switch self {
        case .invalidBackupFile:
            return "This file is not a valid Sunclub backup."
        case .unsupportedBackupVersion:
            return "This backup was created with an unsupported format."
        case .missingStoreFiles:
            return "The backup is missing the data files needed to restore your history."
        case .invalidStoreFilename:
            return "The backup contains an unexpected file name."
        }
    }
}
