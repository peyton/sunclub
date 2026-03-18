import Foundation

nonisolated enum SunscreenDetectionAnswer: String, Sendable {
    case yes = "YES"
    case no = "NO"
}

nonisolated enum SunscreenResponseParser {
    static func parse(_ output: String) -> SunscreenDetectionAnswer {
        let tokens = sanitized(output)
            .split(separator: " ")
            .map(String.init)

        guard let firstToken = tokens.first else {
            return .no
        }

        return firstToken == SunscreenDetectionAnswer.yes.rawValue ? .yes : .no
    }

    static func sanitized(_ output: String) -> String {
        output
            .uppercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
