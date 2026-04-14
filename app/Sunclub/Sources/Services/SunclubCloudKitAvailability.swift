import Foundation

protocol SunclubCloudKitEntitlementProviding {
    func entitlementValue(for key: String) -> Any?
}

struct CodeSignatureCloudKitEntitlementProvider: SunclubCloudKitEntitlementProviding {
    private let executableURL: URL?

    init(bundle: Bundle = .main) {
        executableURL = bundle.executableURL
    }

    init(executableURL: URL?) {
        self.executableURL = executableURL
    }

    func entitlementValue(for key: String) -> Any? {
        guard let executableURL,
              let entitlements = CodeSignatureEntitlementReader.entitlements(in: executableURL) else {
            return nil
        }

        return entitlements[key]
    }
}

enum SunclubCloudKitAvailability {
    private enum EntitlementKey {
        static let containerIdentifiers = "com.apple.developer.icloud-container-identifiers"
        static let services = "com.apple.developer.icloud-services"
    }

    static func validate(containerIdentifier: String) throws {
        let normalizedIdentifier = containerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidContainerIdentifier(normalizedIdentifier) else {
            throw SunclubCloudKitConfigurationError.invalidContainerIdentifier
        }
    }

    static func validateRuntime(
        containerIdentifier: String,
        entitlementProvider: SunclubCloudKitEntitlementProviding = CodeSignatureCloudKitEntitlementProvider()
    ) throws {
        try validate(containerIdentifier: containerIdentifier)

        let containerEntitlement = entitlementProvider.entitlementValue(
            for: EntitlementKey.containerIdentifiers
        )
        guard entitlementContains(containerEntitlement, expected: containerIdentifier) else {
            throw SunclubCloudKitConfigurationError.missingContainerEntitlement(containerIdentifier)
        }

        let servicesEntitlement = entitlementProvider.entitlementValue(for: EntitlementKey.services)
        guard entitlementContains(servicesEntitlement, expected: "CloudKit") else {
            throw SunclubCloudKitConfigurationError.missingCloudKitServiceEntitlement
        }
    }

    private static func isValidContainerIdentifier(_ containerIdentifier: String) -> Bool {
        containerIdentifier.hasPrefix("iCloud.")
            && containerIdentifier.count > "iCloud.".count
            && !containerIdentifier.contains("$(")
    }

    private static func entitlementContains(_ value: Any?, expected: String) -> Bool {
        if let string = value as? String {
            return string == expected || string == "*"
        }

        if let strings = value as? [String] {
            return strings.contains(expected) || strings.contains("*")
        }

        if let array = value as? [Any] {
            return array.contains { item in
                guard let string = item as? String else {
                    return false
                }

                return string == expected || string == "*"
            }
        }

        return false
    }
}

private enum CodeSignatureEndianness {
    case little
    case big
}

private enum CodeSignatureEntitlementReader {
    private struct Slice {
        var offset: Int
        var size: Int
    }

    private struct CodeSignatureLocation {
        var offset: Int
        var size: Int
    }

    private static let machHeader32Size = 28
    private static let machHeader64Size = 32
    private static let fatMagic: UInt32 = 0xcafebabe
    private static let fatMagic64: UInt32 = 0xcafebabf
    private static let machMagic32: UInt32 = 0xfeedface
    private static let machMagic64: UInt32 = 0xfeedfacf
    private static let loadCommandCodeSignature: UInt32 = 0x1d
    private static let codeSignatureSuperBlobMagic: UInt32 = 0xfade0cc0
    private static let embeddedEntitlementsSlot: UInt32 = 5
    private static let embeddedEntitlementsMagic: UInt32 = 0xfade7171

    static func entitlements(in executableURL: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: executableURL, options: [.mappedIfSafe]) else {
            return nil
        }

        for slice in slices(in: data) {
            guard let codeSignature = codeSignatureLocation(in: data, slice: slice),
                  let entitlements = entitlements(in: data, codeSignature: codeSignature) else {
                continue
            }

            return entitlements
        }

        return nil
    }

    private static func slices(in data: Data) -> [Slice] {
        guard let magic = data.uint32(at: 0, endianness: .big) else {
            return []
        }

        if magic == fatMagic || magic == fatMagic64 {
            guard let count = data.uint32(at: 4, endianness: .big) else {
                return []
            }

            let archSize = magic == fatMagic64 ? 32 : 20
            let archOffset = 8
            return (0..<Int(count)).compactMap { index in
                let offset = archOffset + index * archSize

                if magic == fatMagic64 {
                    guard let sliceOffset = data.uint64(at: offset + 8, endianness: .big),
                          let sliceSize = data.uint64(at: offset + 16, endianness: .big),
                          sliceOffset <= UInt64(Int.max),
                          sliceSize <= UInt64(Int.max) else {
                        return nil
                    }

                    return Slice(offset: Int(sliceOffset), size: Int(sliceSize))
                }

                guard let sliceOffset = data.uint32(at: offset + 8, endianness: .big),
                      let sliceSize = data.uint32(at: offset + 12, endianness: .big) else {
                    return nil
                }

                return Slice(offset: Int(sliceOffset), size: Int(sliceSize))
            }
        }

        return [Slice(offset: 0, size: data.count)]
    }

    private static func codeSignatureLocation(in data: Data, slice: Slice) -> CodeSignatureLocation? {
        guard let magic = data.uint32(at: slice.offset, endianness: .little) else {
            return nil
        }

        let headerSize: Int
        switch magic {
        case machMagic32:
            headerSize = machHeader32Size
        case machMagic64:
            headerSize = machHeader64Size
        default:
            return nil
        }

        guard let commandCount = data.uint32(at: slice.offset + 16, endianness: .little) else {
            return nil
        }

        var commandOffset = slice.offset + headerSize
        let sliceEnd = slice.offset + slice.size
        for _ in 0..<Int(commandCount) {
            guard commandOffset + 8 <= sliceEnd,
                  let command = data.uint32(at: commandOffset, endianness: .little),
                  let commandSize = data.uint32(at: commandOffset + 4, endianness: .little),
                  commandSize >= 8 else {
                return nil
            }

            if command == loadCommandCodeSignature {
                guard let signatureOffset = data.uint32(at: commandOffset + 8, endianness: .little),
                      let signatureSize = data.uint32(at: commandOffset + 12, endianness: .little) else {
                    return nil
                }

                return CodeSignatureLocation(
                    offset: slice.offset + Int(signatureOffset),
                    size: Int(signatureSize)
                )
            }

            commandOffset += Int(commandSize)
        }

        return nil
    }

    private static func entitlements(
        in data: Data,
        codeSignature: CodeSignatureLocation
    ) -> [String: Any]? {
        let signatureEnd = codeSignature.offset + codeSignature.size
        guard signatureEnd <= data.count,
              data.uint32(at: codeSignature.offset, endianness: .big) == codeSignatureSuperBlobMagic,
              let count = data.uint32(at: codeSignature.offset + 8, endianness: .big) else {
            return nil
        }

        let indexOffset = codeSignature.offset + 12
        for index in 0..<Int(count) {
            let entryOffset = indexOffset + index * 8
            guard let slot = data.uint32(at: entryOffset, endianness: .big),
                  let blobOffset = data.uint32(at: entryOffset + 4, endianness: .big),
                  slot == embeddedEntitlementsSlot else {
                continue
            }

            let absoluteBlobOffset = codeSignature.offset + Int(blobOffset)
            guard absoluteBlobOffset + 8 <= signatureEnd,
                  data.uint32(at: absoluteBlobOffset, endianness: .big) == embeddedEntitlementsMagic,
                  let blobLength = data.uint32(at: absoluteBlobOffset + 4, endianness: .big),
                  Int(blobLength) >= 8,
                  absoluteBlobOffset + Int(blobLength) <= signatureEnd else {
                return nil
            }

            let payloadStart = absoluteBlobOffset + 8
            let payload = data[payloadStart..<(absoluteBlobOffset + Int(blobLength))]
            return (try? PropertyListSerialization.propertyList(
                from: Data(payload),
                options: [],
                format: nil
            )) as? [String: Any]
        }

        return nil
    }
}

private extension Data {
    func uint32(at offset: Int, endianness: CodeSignatureEndianness) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else {
            return nil
        }

        let bytes = [self[offset], self[offset + 1], self[offset + 2], self[offset + 3]]
        switch endianness {
        case .little:
            return UInt32(bytes[0])
                | UInt32(bytes[1]) << 8
                | UInt32(bytes[2]) << 16
                | UInt32(bytes[3]) << 24
        case .big:
            return UInt32(bytes[0]) << 24
                | UInt32(bytes[1]) << 16
                | UInt32(bytes[2]) << 8
                | UInt32(bytes[3])
        }
    }

    func uint64(at offset: Int, endianness: CodeSignatureEndianness) -> UInt64? {
        guard offset >= 0, offset + 8 <= count else {
            return nil
        }

        let bytes = (0..<8).map { self[offset + $0] }
        switch endianness {
        case .little:
            return bytes.enumerated().reduce(UInt64(0)) { result, element in
                result | UInt64(element.element) << UInt64(element.offset * 8)
            }
        case .big:
            return bytes.reduce(UInt64(0)) { result, byte in
                result << 8 | UInt64(byte)
            }
        }
    }
}

enum SunclubCloudKitConfigurationError: LocalizedError, Equatable, Sendable {
    case invalidContainerIdentifier
    case missingCloudKitServiceEntitlement
    case missingContainerEntitlement(String)

    var errorDescription: String? {
        switch self {
        case .invalidContainerIdentifier:
            return "Sunclub couldn't start iCloud because the CloudKit container is invalid."
        case .missingCloudKitServiceEntitlement:
            return "Sunclub couldn't start iCloud because this build is missing the CloudKit service entitlement."
        case let .missingContainerEntitlement(containerIdentifier):
            return "Sunclub couldn't start iCloud because this build is missing the \(containerIdentifier) container entitlement."
        }
    }
}
