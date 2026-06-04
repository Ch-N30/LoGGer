import Foundation

/// A terminal-oriented formatter that renders compact lines for low-severity entries and framed blocks for high-severity entries.
///
/// `PrettyFormatter` can apply the ANSI color from `LogLevel.ansiColor` to the whole formatted output when color is enabled.
///
/// Example:
/// ```swift
/// let formatter = PrettyFormatter(components: .full)
/// let output = formatter.format(entry)
/// ```
public final class PrettyFormatter: LogFormatter {
    /// A set of optional sections included in formatted log output.
    ///
    /// Example:
    /// ```swift
    /// let components: PrettyFormatter.Components = [.timestamp, .category, .location]
    /// let formatter = PrettyFormatter(components: components)
    /// ```
    public struct Components: OptionSet, Sendable {
        /// The raw bit mask used by the option set.
        public let rawValue: Int

        /// Includes the entry timestamp formatted as `HH:mm:ss`.
        public static let timestamp = Components(rawValue: 1 << 0)

        /// Includes the entry category when one is present.
        public static let category = Components(rawValue: 1 << 1)

        /// Includes the source file and line.
        public static let location = Components(rawValue: 1 << 2)

        /// Includes the thread on which formatting is executed.
        ///
        /// `LogEntry` does not store the original logging thread, so this component describes formatter execution context only.
        public static let threadInfo = Components(rawValue: 1 << 3)

        /// Includes structured metadata when one is present.
        public static let metadata = Components(rawValue: 1 << 4)

        /// Includes visual separators between grouped sections.
        public static let separator = Components(rawValue: 1 << 5)

        /// A compact preset that includes timestamp and category.
        public static let minimal: Components = [.timestamp, .category]

        /// A full preset that includes every optional section.
        public static let full: Components = [
            .timestamp,
            .category,
            .location,
            .threadInfo,
            .metadata,
            .separator
        ]

        /// Creates a component set from a raw bit mask.
        ///
        /// - Parameter rawValue: The raw bit mask used by the option set.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    /// A default formatter configured with `.full` components.
    ///
    /// Example:
    /// ```swift
    /// let output = PrettyFormatter.default.format(entry)
    /// ```
    public static let `default` = PrettyFormatter(components: .full)

    /// A formatter configured with `.minimal` components.
    ///
    /// Example:
    /// ```swift
    /// let output = PrettyFormatter.minimal.format(entry)
    /// ```
    public static let minimal = PrettyFormatter(components: .minimal)

    /// The optional sections included in formatted output.
    public let components: Components

    /// The time zone identifier used for timestamp formatting.
    ///
    /// A `nil` value means the formatter uses the current system time zone at formatting time.
    public let timeZoneIdentifier: String?

    /// A Boolean value that controls whether ANSI color escape sequences are included in formatted output.
    ///
    /// Keep this disabled for Xcode and other consoles that do not interpret ANSI colors.
    public let isColorEnabled: Bool

    /// A Boolean value that controls whether level emoji are included in formatted output.
    ///
    /// Keep this disabled for production IDE logs where stable plain-text output matters more than decoration.
    public let isEmojiEnabled: Bool

    /// A Boolean value that controls whether Unicode separators, arrows, and borders are included in formatted output.
    ///
    /// Keep this disabled for Xcode and other consoles that do not render box-drawing characters consistently.
    public let usesUnicodeSymbols: Bool

    /// Creates a pretty formatter.
    ///
    /// - Parameters:
    ///   - components: The optional sections included in formatted output.
    ///   - timeZoneIdentifier: A time zone identifier used for timestamp formatting, or `nil` to use the current system time zone.
    ///   - isColorEnabled: Whether ANSI color escape sequences are included in formatted output.
    ///   - isEmojiEnabled: Whether level emoji are included in formatted output.
    ///   - usesUnicodeSymbols: Whether Unicode separators, arrows, and borders are included in formatted output.
    public init(
        components: Components = .full,
        timeZoneIdentifier: String? = nil,
        isColorEnabled: Bool = false,
        isEmojiEnabled: Bool = false,
        usesUnicodeSymbols: Bool = false
    ) {
        self.components = components
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isColorEnabled = isColorEnabled
        self.isEmojiEnabled = isEmojiEnabled
        self.usesUnicodeSymbols = usesUnicodeSymbols
    }

    /// Converts a log entry into a compact line or an expanded framed block.
    ///
    /// Verbose, debug, and info entries are rendered as compact single-line output.
    /// Warning, error, and fault entries are rendered as framed multi-line blocks.
    ///
    /// - Parameter entry: The log entry to format.
    /// - Returns: A terminal-oriented formatted string, optionally wrapped in the entry level's ANSI color.
    public func format(_ entry: LogEntry) -> String {
        switch entry.level {
        case .verbose, .debug, .info:
            return colorized(formatCompactLine(for: entry), level: entry.level)
        case .warning, .error, .fault:
            return colorized(formatExpandedBlock(for: entry), level: entry.level)
        }
    }

    private func formatCompactLine(for entry: LogEntry) -> String {
        var leadingParts = [levelDescription(for: entry.level)]

        if components.contains(.category), let category = entry.category {
            leadingParts.append(category)
        }

        leadingParts.append(entry.message)

        var line = leadingParts.joined(separator: " ")

        if components.contains(.timestamp) {
            line += "  \(timestamp(for: entry.date))"
        }

        return line
    }

    private func formatExpandedBlock(for entry: LogEntry) -> String {
        let headerSeparator = components.contains(.separator) ? self.headerSeparator : "  "
        var headerParts = [levelDescription(for: entry.level)]

        if components.contains(.category), let category = entry.category {
            headerParts.append(category)
        }

        if components.contains(.timestamp) {
            headerParts.append(timestamp(for: entry.date))
        }

        let header = headerParts.joined(separator: headerSeparator)
        var contentLines = [header]
        contentLines.append(contentsOf: entry.message.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))

        if components.contains(.location) {
            contentLines.append("\(arrow) \(location(for: entry))")
        }

        if components.contains(.threadInfo) {
            contentLines.append("\(arrow) thread: \(threadDescription())")
        }

        if components.contains(.metadata), let metadataLines = metadataLines(for: entry.metadata) {
            contentLines.append("\(arrow) metadata:")
            contentLines.append(contentsOf: metadataLines)
        }

        let width = contentLines.map(\.count).max() ?? 0
        var lines = [topBorder(width: width)]
        lines.append(framedLine(header, width: width))

        if components.contains(.separator), contentLines.count > 1 {
            lines.append(middleBorder(width: width))
        }

        for line in contentLines.dropFirst() {
            lines.append(framedLine(line, width: width))
        }

        lines.append(bottomBorder(width: width))
        return lines.joined(separator: "\n")
    }

    private func colorized(_ text: String, level: LogLevel) -> String {
        guard isColorEnabled else {
            return text
        }

        return "\(level.ansiColor)\(text)\(Self.ansiReset)"
    }

    private func levelDescription(for level: LogLevel) -> String {
        isEmojiEnabled ? "\(level.emoji) \(level.label)" : level.label
    }

    private var headerSeparator: String {
        usesUnicodeSymbols ? "  │  " : " | "
    }

    private var arrow: String {
        usesUnicodeSymbols ? "→" : "->"
    }

    private func timestamp(for date: Date) -> String {
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

    private func twoDigitString(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private func location(for entry: LogEntry) -> String {
        "\(fileName(from: entry.file)):\(entry.line)"
    }

    private func fileName(from file: StaticString) -> String {
        let path = String(describing: file)
        return path.split { character in
            character == "/" || character == "\\"
        }.last.map(String.init) ?? path
    }

    private func threadDescription() -> String {
        Thread.isMainThread ? "main" : "background"
    }

    private func metadataLines(for metadata: [String: any Sendable]?) -> [String]? {
        guard let metadata, !metadata.isEmpty else {
            return nil
        }

        return metadata
            .sorted { $0.key < $1.key }
            .map { "   \($0.key)=\(String(describing: $0.value))" }
    }

    private func topBorder(width: Int) -> String {
        if usesUnicodeSymbols {
            return "╔\(String(repeating: "═", count: width + 2))╗"
        }

        return "+\(String(repeating: "-", count: width + 2))+"
    }

    private func middleBorder(width: Int) -> String {
        if usesUnicodeSymbols {
            return "╠\(String(repeating: "═", count: width + 2))╣"
        }

        return "+\(String(repeating: "-", count: width + 2))+"
    }

    private func bottomBorder(width: Int) -> String {
        if usesUnicodeSymbols {
            return "╚\(String(repeating: "═", count: width + 2))╝"
        }

        return "+\(String(repeating: "-", count: width + 2))+"
    }

    private func framedLine(_ text: String, width: Int) -> String {
        let padding = String(repeating: " ", count: max(0, width - text.count))
        if usesUnicodeSymbols {
            return "║ \(text)\(padding) ║"
        }

        return "| \(text)\(padding) |"
    }

    private static let ansiReset = "\u{001B}[0m"
}
