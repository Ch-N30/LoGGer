/// A formatter that renders every log entry as a short single-line message.
///
/// Use this formatter for Xcode console output, local development, and other places where stable
/// plain text is more useful than decoration.
///
/// Example:
/// ```swift
/// let formatter = CompactFormatter()
/// formatter.format(entry)
/// ```
public final class CompactFormatter: LogFormatter {
    /// A default compact formatter configured with timestamp and category output.
    public static let `default` = CompactFormatter()

    /// A compact formatter that includes only level and message.
    public static let minimal = CompactFormatter(includesTimestamp: false, includesCategory: false)

    /// A Boolean value that controls whether timestamps are included.
    public let includesTimestamp: Bool

    /// A Boolean value that controls whether categories are included.
    public let includesCategory: Bool

    /// A Boolean value that controls whether source file and line are included.
    public let includesLocation: Bool

    /// A Boolean value that controls whether metadata key-value pairs are included.
    public let includesMetadata: Bool

    /// The time zone identifier used for timestamp formatting.
    ///
    /// A `nil` value means the formatter uses the current system time zone at formatting time.
    public let timeZoneIdentifier: String?

    /// Creates a compact formatter.
    ///
    /// - Parameters:
    ///   - includesTimestamp: Whether timestamps are included.
    ///   - includesCategory: Whether categories are included.
    ///   - includesLocation: Whether source file and line are included.
    ///   - includesMetadata: Whether metadata key-value pairs are included.
    ///   - timeZoneIdentifier: A time zone identifier used for timestamp formatting, or `nil` to use the current system time zone.
    public init(
        includesTimestamp: Bool = true,
        includesCategory: Bool = true,
        includesLocation: Bool = false,
        includesMetadata: Bool = false,
        timeZoneIdentifier: String? = nil
    ) {
        self.includesTimestamp = includesTimestamp
        self.includesCategory = includesCategory
        self.includesLocation = includesLocation
        self.includesMetadata = includesMetadata
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// Converts a log entry into a single-line plain-text string.
    ///
    /// - Parameter entry: The log entry to format.
    /// - Returns: A compact formatted string.
    public func format(_ entry: LogEntry) -> String {
        var parts = [entry.level.label]

        if includesCategory, let category = entry.category {
            parts.append(category)
        }

        parts.append(entry.message)

        if includesLocation {
            parts.append("\(FormatterSupport.fileName(from: entry.file)):\(entry.line)")
        }

        if includesMetadata {
            parts.append(
                contentsOf: FormatterSupport
                    .metadataPairs(for: entry.metadata)
                    .map { "\($0.key)=\($0.value)" }
            )
        }

        var line = parts.joined(separator: " ")

        if includesTimestamp {
            line += "  \(FormatterSupport.timeString(for: entry.date, timeZoneIdentifier: timeZoneIdentifier))"
        }

        return line
    }
}
