import Foundation

/// A formatter that renders log entries as JSON.
///
/// Use this formatter for structured log pipelines, file exports, and transports that expect
/// machine-readable payloads.
///
/// Example:
/// ```swift
/// let formatter = JSONFormatter()
/// formatter.format(entry)
/// ```
public final class JSONFormatter: LogFormatter {
    /// A default compact JSON formatter.
    public static let `default` = JSONFormatter()

    /// A pretty-printed JSON formatter for diagnostics and snapshots.
    public static let prettyPrinted = JSONFormatter(isPrettyPrinted: true)

    /// A Boolean value that controls whether source file, function, and line are included.
    public let includesLocation: Bool

    /// A Boolean value that controls whether metadata is included.
    public let includesMetadata: Bool

    /// A Boolean value that controls whether output is formatted with indentation.
    public let isPrettyPrinted: Bool

    /// The time zone identifier used for timestamp formatting.
    ///
    /// A `nil` value means the formatter uses UTC-style ISO 8601 output from `ISO8601DateFormatter`.
    public let timeZoneIdentifier: String?

    /// Creates a JSON formatter.
    ///
    /// - Parameters:
    ///   - includesLocation: Whether source file, function, and line are included.
    ///   - includesMetadata: Whether metadata is included.
    ///   - isPrettyPrinted: Whether output is formatted with indentation.
    ///   - timeZoneIdentifier: A time zone identifier used for timestamp formatting, or `nil` for default ISO 8601 behavior.
    public init(
        includesLocation: Bool = true,
        includesMetadata: Bool = true,
        isPrettyPrinted: Bool = false,
        timeZoneIdentifier: String? = nil
    ) {
        self.includesLocation = includesLocation
        self.includesMetadata = includesMetadata
        self.isPrettyPrinted = isPrettyPrinted
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// Converts a log entry into a JSON object string.
    ///
    /// Metadata values that are not native JSON values are converted with `String(describing:)`.
    ///
    /// - Parameter entry: The log entry to format.
    /// - Returns: A JSON string that represents the entry.
    public func format(_ entry: LogEntry) -> String {
        var object: [String: Any] = [
            "id": entry.id.uuidString,
            "timestamp": FormatterSupport.iso8601String(for: entry.date, timeZoneIdentifier: timeZoneIdentifier),
            "level": entry.level.label,
            "message": entry.message
        ]

        if let category = entry.category {
            object["category"] = category
        }

        if includesLocation {
            object["file"] = FormatterSupport.fileName(from: entry.file)
            object["function"] = String(describing: entry.function)
            object["line"] = Int(entry.line)
        }

        if includesMetadata, let metadata = jsonMetadata(from: entry.metadata) {
            object["metadata"] = metadata
        }

        var options: JSONSerialization.WritingOptions = [.sortedKeys]
        if isPrettyPrinted {
            options.insert(.prettyPrinted)
        }

        guard
            JSONSerialization.isValidJSONObject(object),
            let data = try? JSONSerialization.data(withJSONObject: object, options: options),
            let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return string
    }

    private func jsonMetadata(from metadata: [String: any Sendable]?) -> [String: Any]? {
        guard let metadata, !metadata.isEmpty else {
            return nil
        }

        return metadata.reduce(into: [:]) { result, pair in
            result[pair.key] = FormatterSupport.jsonValue(from: pair.value)
        }
    }
}
