import Foundation

/// An immutable record that contains all contextual information for a single log message.
public struct LogEntry: Sendable {
    /// A stable identifier for the log entry.
    public let id: UUID

    /// The human-readable log message.
    public let message: String

    /// The severity level of the log message.
    public let level: LogLevel

    /// The moment when the log entry was created.
    public let date: Date

    /// The source file that created the log entry.
    public let file: StaticString

    /// The function that created the log entry.
    public let function: StaticString

    /// The source line that created the log entry.
    public let line: UInt

    /// An optional logical category that can be used to group related log entries.
    public let category: String?

    /// Optional structured metadata attached to the log entry.
    public let metadata: [String: any Sendable]?

    /// Creates an immutable log entry.
    ///
    /// - Parameters:
    ///   - message: The human-readable log message.
    ///   - level: The severity level of the log message.
    ///   - category: A logical category that groups related entries.
    ///   - metadata: Structured metadata attached to the entry.
    ///   - id: A stable identifier for the entry.
    ///   - date: The moment when the entry was created.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public init(
        message: String,
        level: LogLevel,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        id: UUID = UUID(),
        date: Date = Date(),
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        self.id = id
        self.message = message
        self.level = level
        self.date = date
        self.file = file
        self.function = function
        self.line = line
        self.category = category
        self.metadata = metadata
    }
}
