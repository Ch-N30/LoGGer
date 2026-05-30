/// A severity level that describes the importance of a log message.
public enum LogLevel: Int, Comparable, CaseIterable, CustomStringConvertible, Sendable {
    /// Verbose diagnostic output that is usually useful only during detailed troubleshooting.
    case verbose

    /// Debug output intended for development-time diagnostics.
    case debug

    /// Informational output that describes normal application behavior.
    case info

    /// A recoverable problem or suspicious state that should be visible during diagnostics.
    case warning

    /// A failure that prevented an operation from completing successfully.
    case error

    /// A critical failure that indicates a serious consistency or runtime problem.
    case fault

    /// A compact emoji representation of the log level.
    public var emoji: String {
        switch self {
        case .verbose:
            return "🔎"
        case .debug:
            return "🐞"
        case .info:
            return "ℹ️"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        case .fault:
            return "💥"
        }
    }

    /// An uppercase text label suitable for terminal and file output.
    public var label: String {
        switch self {
        case .verbose:
            return "VERBOSE"
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warning:
            return "WARNING"
        case .error:
            return "ERROR"
        case .fault:
            return "FAULT"
        }
    }

    /// The ANSI escape code that can be used to color this level in Terminal output.
    public var ansiColor: String {
        switch self {
        case .verbose:
            return "\u{001B}[0;37m"
        case .debug:
            return "\u{001B}[0;36m"
        case .info:
            return "\u{001B}[0;32m"
        case .warning:
            return "\u{001B}[0;33m"
        case .error:
            return "\u{001B}[0;31m"
        case .fault:
            return "\u{001B}[1;35m"
        }
    }

    /// A textual representation of the log level.
    public var description: String {
        label
    }

    /// Returns a Boolean value that indicates whether the left-hand level is less severe than the right-hand level.
    ///
    /// - Parameters:
    ///   - lhs: The level on the left side of the comparison.
    ///   - rhs: The level on the right side of the comparison.
    /// - Returns: `true` when `lhs` has a lower raw value than `rhs`; otherwise, `false`.
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
