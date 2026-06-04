/// A formatter that renders log entries as logfmt-style key-value pairs.
///
/// Use this formatter when logs should stay grep-friendly while still being easy to parse.
///
/// Example:
/// ```swift
/// let formatter = KeyValueFormatter()
/// formatter.format(entry)
/// ```
public final class KeyValueFormatter: LogFormatter {
    /// A default key-value formatter.
    public static let `default` = KeyValueFormatter()

    /// A Boolean value that controls whether source file and line are included.
    public let includesLocation: Bool

    /// A Boolean value that controls whether metadata key-value pairs are included.
    public let includesMetadata: Bool

    /// The time zone identifier used for timestamp formatting.
    ///
    /// A `nil` value means the formatter uses the current system time zone at formatting time.
    public let timeZoneIdentifier: String?

    /// Creates a key-value formatter.
    ///
    /// - Parameters:
    ///   - includesLocation: Whether source file and line are included.
    ///   - includesMetadata: Whether metadata key-value pairs are included.
    ///   - timeZoneIdentifier: A time zone identifier used for timestamp formatting, or `nil` to use the current system time zone.
    public init(
        includesLocation: Bool = true,
        includesMetadata: Bool = true,
        timeZoneIdentifier: String? = nil
    ) {
        self.includesLocation = includesLocation
        self.includesMetadata = includesMetadata
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// Converts a log entry into a logfmt-style string.
    ///
    /// - Parameter entry: The log entry to format.
    /// - Returns: A formatted string made of stable key-value pairs.
    public func format(_ entry: LogEntry) -> String {
        var pairs: [(key: String, value: String)] = [
            ("time", FormatterSupport.iso8601String(for: entry.date, timeZoneIdentifier: timeZoneIdentifier)),
            ("level", entry.level.label),
            ("message", entry.message)
        ]

        if let category = entry.category {
            pairs.append(("category", category))
        }

        if includesLocation {
            pairs.append(("file", FormatterSupport.fileName(from: entry.file)))
            pairs.append(("line", String(entry.line)))
        }

        if includesMetadata {
            pairs.append(contentsOf: FormatterSupport.metadataPairs(for: entry.metadata))
        }

        return pairs
            .map { "\($0.key)=\(FormatterSupport.logfmtValue($0.value))" }
            .joined(separator: " ")
    }
}
