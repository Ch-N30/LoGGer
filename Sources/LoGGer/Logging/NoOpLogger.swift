/// A logger implementation that intentionally drops every log call.
///
/// Use `NoOpLogger` in tests, previews, UI tests, disabled feature branches, or any place where
/// callers should receive an `iLog` dependency but logging must produce no side effects.
///
/// `NoOpLogger` never evaluates the `message` autoclosure.
///
/// Example:
/// ```swift
/// let logger: any iLog = NoOpLogger()
/// logger.debug(expensiveDebugMessage())
/// ```
public final class NoOpLogger: iLog {
    /// Creates a no-op logger.
    public init() {}

    /// Drops a log message without evaluating it.
    ///
    /// - Parameters:
    ///   - message: The message expression, which is intentionally not evaluated.
    ///   - level: The severity level of the message.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public func log(
        _ message: @autoclosure () -> String,
        level: LogLevel,
        category: String?,
        metadata: [String: any Sendable]?,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) {}

    /// Returns this logger because scoped no-op logging is still no-op logging.
    ///
    /// - Parameter category: The ignored category.
    /// - Returns: This no-op logger.
    public func scoped(to category: String) -> any iLog {
        self
    }
}
