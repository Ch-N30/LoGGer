import Foundation

/// A result builder that creates logger destinations from a declarative block.
///
/// The builder supports plain destination expressions, optional `if` blocks, and `for` loops.
///
/// Example:
/// ```swift
/// let logger = Logger {
///     ConsoleDestination()
///
///     if isDevelopment {
///         ConsoleDestination()
///             .withFormatter(PrettyFormatter(components: .full))
///             .withFilter(LevelFilter(.verbose))
///     }
/// }
/// ```
@resultBuilder
public struct LoggerBuilder {
    /// Converts a destination expression into a destination list.
    ///
    /// - Parameter expression: A destination declared in a logger builder block.
    /// - Returns: A one-element destination list.
    public static func buildExpression(_ expression: any LogDestination) -> [any LogDestination] {
        [expression]
    }

    /// Passes through an existing destination list.
    ///
    /// - Parameter expression: A destination list declared in a logger builder block.
    /// - Returns: The original destination list.
    public static func buildExpression(_ expression: [any LogDestination]) -> [any LogDestination] {
        expression
    }

    /// Combines destination lists from the builder block.
    ///
    /// - Parameter components: Destination lists produced by child expressions.
    /// - Returns: A flattened destination list.
    public static func buildBlock(_ components: [any LogDestination]...) -> [any LogDestination] {
        components.flatMap { $0 }
    }

    /// Combines destination lists produced by a `for` loop.
    ///
    /// - Parameter components: Destination lists produced by loop iterations.
    /// - Returns: A flattened destination list.
    public static func buildArray(_ components: [[any LogDestination]]) -> [any LogDestination] {
        components.flatMap { $0 }
    }

    /// Handles an optional destination list produced by an `if` block without `else`.
    ///
    /// - Parameter component: The optional destination list.
    /// - Returns: The contained destinations, or an empty list when the optional branch is not used.
    public static func buildOptional(_ component: [any LogDestination]?) -> [any LogDestination] {
        component ?? []
    }
}

/// The main public logging façade.
///
/// `Logger` is intentionally not a singleton. Create and inject instances at application boundaries.
/// Calls are synchronous at the call site and enqueue asynchronous delivery through `LogActor`.
///
/// Example:
/// ```swift
/// let logger = Logger {
///     ConsoleDestination()
///         .withFilter(LevelFilter(.debug))
/// }
///
/// logger.info("Application started", category: "Lifecycle")
/// ```
public final class Logger: Sendable {
    let destinations: [any LogDestination]
    private let actor: LogActor

    /// Creates a logger from destinations declared in a builder block.
    ///
    /// - Parameter builder: A builder that returns the destinations used by the logger.
    public init(@LoggerBuilder _ builder: () -> [any LogDestination]) {
        let destinations = builder()
        self.destinations = destinations
        self.actor = LogActor(destinations: destinations)
    }

    /// Logs a message at the specified level.
    ///
    /// The `message` expression is evaluated lazily. It is not evaluated when all destinations can
    /// be rejected by message-independent filters such as `LevelFilter` and `CategoryFilter`.
    ///
    /// - Note: A `BlockFilter` can inspect `entry.message`, so the logger must evaluate the message
    /// when such a filter is present in a destination that may otherwise accept the entry.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate only when a destination may accept the entry.
    ///   - level: The severity level of the message.
    ///   - category: An optional logical category for the entry.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public func log(
        _ message: @autoclosure () -> String,
        level: LogLevel,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        guard mayAcceptEntry(
            level: level,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        ) else {
            return
        }

        let entry = LogEntry(
            message: message(),
            level: level,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )

        Task { [actor] in
            await actor.process(entry)
        }
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
    public func verbose(
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
    public func debug(
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
    public func info(
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
    public func warning(
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
    public func error(
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
    public func fault(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .fault, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Creates a scoped logger that uses a fixed category.
    ///
    /// Example:
    /// ```swift
    /// let networkLogger = logger.scoped(to: "Network")
    /// networkLogger.debug("Request started")
    /// ```
    ///
    /// - Parameter category: The category applied to every entry logged through the scoped logger.
    /// - Returns: A scoped logger that forwards entries to this logger.
    public func scoped(to category: String) -> ScopedLogger {
        ScopedLogger(logger: self, category: category)
    }

    private func mayAcceptEntry(
        level: LogLevel,
        category: String?,
        metadata: [String: any Sendable]?,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) -> Bool {
        destinations.contains { destination in
            destination.filters.allSatisfy { filter in
                guard let preflightFilter = filter as? any LogPreflightFilter else {
                    return true
                }

                return preflightFilter.isAllowed(
                    level: level,
                    category: category,
                    metadata: metadata,
                    file: file,
                    function: function,
                    line: line
                )
            }
        }
    }
}

/// A logger wrapper that applies a fixed category to every emitted entry.
///
/// Create scoped loggers with `Logger.scoped(to:)`.
///
/// Example:
/// ```swift
/// let authLogger = logger.scoped(to: "Auth")
/// authLogger.error("Token refresh failed")
/// ```
public struct ScopedLogger: Sendable {
    private let logger: Logger
    private let category: String

    /// Creates a scoped logger.
    ///
    /// - Parameters:
    ///   - logger: The logger that receives scoped log calls.
    ///   - category: The category applied to every entry.
    public init(logger: Logger, category: String) {
        self.logger = logger
        self.category = category
    }

    /// Logs a message at the specified level with the scoped category.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - level: The severity level of the message.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public func log(
        _ message: @autoclosure () -> String,
        level: LogLevel,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        logger.log(message(), level: level, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a verbose diagnostic message with the scoped category.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public func verbose(
        _ message: @autoclosure () -> String,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .verbose, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a debug diagnostic message with the scoped category.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public func debug(
        _ message: @autoclosure () -> String,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .debug, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs an informational message with the scoped category.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public func info(
        _ message: @autoclosure () -> String,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .info, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a warning message with the scoped category.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public func warning(
        _ message: @autoclosure () -> String,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .warning, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs an error message with the scoped category.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public func error(
        _ message: @autoclosure () -> String,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .error, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a fault message with the scoped category.
    ///
    /// - Parameters:
    ///   - message: The message expression to evaluate lazily.
    ///   - metadata: Optional structured metadata attached to the entry.
    ///   - file: The source file that creates the entry.
    ///   - function: The function that creates the entry.
    ///   - line: The source line that creates the entry.
    public func fault(
        _ message: @autoclosure () -> String,
        metadata: [String: any Sendable]? = nil,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        log(message(), level: .fault, metadata: metadata, file: file, function: function, line: line)
    }
}

private protocol LogPreflightFilter: LogFilter {
    func isAllowed(
        level: LogLevel,
        category: String?,
        metadata: [String: any Sendable]?,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) -> Bool
}

extension LevelFilter: LogPreflightFilter {
    fileprivate func isAllowed(
        level: LogLevel,
        category: String?,
        metadata: [String: any Sendable]?,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) -> Bool {
        level >= minLevel
    }
}

extension CategoryFilter: LogPreflightFilter {
    fileprivate func isAllowed(
        level: LogLevel,
        category: String?,
        metadata: [String: any Sendable]?,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) -> Bool {
        guard let category else {
            return false
        }

        return categories.contains(category)
    }
}

extension CompositeFilter: LogPreflightFilter {
    fileprivate func isAllowed(
        level: LogLevel,
        category: String?,
        metadata: [String: any Sendable]?,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) -> Bool {
        switch mode {
        case .and:
            return filters.allSatisfy { filter in
                guard let preflightFilter = filter as? any LogPreflightFilter else {
                    return true
                }

                return preflightFilter.isAllowed(
                    level: level,
                    category: category,
                    metadata: metadata,
                    file: file,
                    function: function,
                    line: line
                )
            }
        case .or:
            var hasUnknownFilter = false

            for filter in filters {
                guard let preflightFilter = filter as? any LogPreflightFilter else {
                    hasUnknownFilter = true
                    continue
                }

                if preflightFilter.isAllowed(
                    level: level,
                    category: category,
                    metadata: metadata,
                    file: file,
                    function: function,
                    line: line
                ) {
                    return true
                }
            }

            return hasUnknownFilter
        }
    }
}
