import Foundation

enum FormatterSupport {
    static func timeString(for date: Date, timeZoneIdentifier: String?) -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZoneIdentifier, let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
        } else {
            calendar.timeZone = .current
        }

        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return [
            twoDigitString(components.hour ?? 0),
            twoDigitString(components.minute ?? 0),
            twoDigitString(components.second ?? 0)
        ].joined(separator: ":")
    }

    static func iso8601String(for date: Date, timeZoneIdentifier: String?) -> String {
        let formatter = ISO8601DateFormatter()
        if let timeZoneIdentifier, let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timeZone
        }

        return formatter.string(from: date)
    }

    static func fileName(from file: StaticString) -> String {
        let path = String(describing: file)
        return path.split { character in
            character == "/" || character == "\\"
        }.last.map(String.init) ?? path
    }

    static func metadataPairs(for metadata: [String: any Sendable]?) -> [(key: String, value: String)] {
        guard let metadata, !metadata.isEmpty else {
            return []
        }

        return metadata
            .sorted { $0.key < $1.key }
            .map { ($0.key, String(describing: $0.value)) }
    }

    static func logfmtValue(_ value: String) -> String {
        guard valueNeedsQuoting(value) else {
            return value
        }

        return "\"\(escapedLogfmtValue(value))\""
    }

    static func jsonValue(from value: any Sendable) -> Any {
        switch value {
        case let value as String:
            return value
        case let value as Bool:
            return value
        case let value as Int:
            return value
        case let value as Int8:
            return Int(value)
        case let value as Int16:
            return Int(value)
        case let value as Int32:
            return Int(value)
        case let value as Int64:
            return value
        case let value as UInt:
            return value <= UInt(Int.max) ? Int(value) : String(value)
        case let value as UInt8:
            return Int(value)
        case let value as UInt16:
            return Int(value)
        case let value as UInt32:
            return value <= UInt32(Int.max) ? Int(value) : String(value)
        case let value as UInt64:
            return value <= UInt64(Int.max) ? Int(value) : String(value)
        case let value as Float:
            return value.isFinite ? value : String(describing: value)
        case let value as Double:
            return value.isFinite ? value : String(describing: value)
        default:
            return String(describing: value)
        }
    }

    private static func twoDigitString(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private static func valueNeedsQuoting(_ value: String) -> Bool {
        value.isEmpty || value.contains { character in
            character.isWhitespace || character == "\"" || character == "\\"
        }
    }

    private static func escapedLogfmtValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
