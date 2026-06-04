/// A logging abstraction for dependency injection.
///
/// Depend on `iLog` in application services, view models, and use cases when the caller should not
/// know which concrete logger implementation is used.
///
/// Example:
/// ```swift
/// final class TournamentListViewModel {
///     private let logger: any iLog
///
///     init(logger: any iLog) {
///         self.logger = logger
///     }
/// }
/// ```
public protocol iLog: Sendable {
    /// Logs a message at the specified level.
    ///
    /// The `message` expression is evaluated lazily by the concrete logger.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate only when it is needed.
    ///   - level: The severity level of the message.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    func log(
        _ message: @autoclosure () -> String,
        level: LogLevel,
        category: String?,
        metadata: [String: any Sendable]?,
        file: StaticString,
        function: StaticString,
        line: UInt
    )

    /// Creates a scoped logger that applies the specified category.
    ///
    /// - Parameter category: The category applied to scoped log entries.
    /// - Returns: A scoped logger that forwards entries to the underlying logger.
    func scoped(to category: String) -> ScopedLogger
}

public extension iLog {
    /// Logs a message at the specified level.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - level: The severity level of the message.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    func log(
        _ message: @autoclosure () -> String,
        level: LogLevel,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(
            message(),
            level: level,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Logs a verbose diagnostic message.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    func verbose(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .verbose, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a debug diagnostic message.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    func debug(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .debug, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs an informational message.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    func info(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .info, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a warning message.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    func warning(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .warning, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs an error message.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    func error(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .error, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a fault message.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    func fault(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .fault, category: category, metadata: metadata, file: file, function: function, line: line)
    }
}
