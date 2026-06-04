/// A type that converts a log entry into a textual representation.
///
/// Formatters are `Sendable`, so they can be shared with actors and other concurrent logging components.
///
/// Example:
/// ```swift
/// let formatter: any LogFormatter = PrettyFormatter.default
/// let text = formatter.format(entry)
/// ```
public protocol LogFormatter: Sendable {
    /// Converts the specified log entry into a string.
    ///
    /// - Parameter entry: The log entry to format.
    /// - Returns: A formatted string that represents the entry.
    func format(_ entry: LogEntry) -> String
}
