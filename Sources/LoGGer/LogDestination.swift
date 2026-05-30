import Foundation

/// A destination that receives log entries after filtering and writes them to a concrete output.
///
/// Destinations own their formatter and filters, which lets one logger fan out the same entry to
/// differently formatted outputs.
///
/// Example:
/// ```swift
/// let destination = ConsoleDestination(
///     formatter: PrettyFormatter.minimal,
///     filters: [LevelFilter(.info)]
/// )
/// ```
public protocol LogDestination: Sendable {
    /// The formatter used by the destination when producing textual output.
    var formatter: any LogFormatter { get }

    /// The filters that decide whether an entry should be written to the destination.
    var filters: [any LogFilter] { get }

    /// Writes a log entry to the destination.
    ///
    /// - Parameter entry: The log entry to write.
    /// - Throws: An error when the destination cannot write the entry.
    func write(_ entry: LogEntry) async throws
}

public extension LogDestination {
    /// Returns whether the destination accepts the specified entry.
    ///
    /// All filters must allow the entry. An empty filter list accepts every entry.
    ///
    /// Example:
    /// ```swift
    /// if destination.accepts(entry) {
    ///     try await destination.write(entry)
    /// }
    /// ```
    ///
    /// - Parameter entry: The log entry to evaluate.
    /// - Returns: `true` when every filter allows the entry; otherwise, `false`.
    func accepts(_ entry: LogEntry) -> Bool {
        filters.allSatisfy { $0.isAllowed(entry) }
    }
}

/// A destination that writes formatted log entries to the console with `print`.
///
/// Example:
/// ```swift
/// let destination = ConsoleDestination()
/// try await destination.write(entry)
/// ```
public final class ConsoleDestination: LogDestination {
    /// The formatter used before printing an entry.
    public let formatter: any LogFormatter

    /// The filters that decide whether an entry should be printed.
    public let filters: [any LogFilter]

    /// Creates a console destination.
    ///
    /// - Parameters:
    ///   - formatter: The formatter used before printing an entry.
    ///   - filters: The filters that decide whether an entry should be printed.
    public init(
        formatter: any LogFormatter = PrettyFormatter.default,
        filters: [any LogFilter] = []
    ) {
        self.formatter = formatter
        self.filters = filters
    }

    /// Prints the formatted entry to standard output.
    ///
    /// - Parameter entry: The log entry to print.
    public func write(_ entry: LogEntry) async throws {
        print(formatter.format(entry))
    }
}

/// An actor that coordinates asynchronous log entry delivery to multiple destinations.
///
/// `LogActor` does not own global state and is not a singleton. Create as many instances as the
/// application needs for its logging boundaries.
///
/// Example:
/// ```swift
/// let logger = LogActor(destinations: [ConsoleDestination()])
/// await logger.process(entry)
/// ```
public actor LogActor {
    private let destinations: [any LogDestination]

    /// Creates a log actor with the specified destinations.
    ///
    /// - Parameter destinations: The destinations that can receive processed entries.
    public init(destinations: [any LogDestination]) {
        self.destinations = destinations
    }

    /// Processes a log entry by sending it to every destination that accepts it.
    ///
    /// Accepted destinations are written in parallel with `withTaskGroup`. Write failures are
    /// reported to standard error and do not escape this method.
    ///
    /// - Parameter entry: The log entry to process.
    public func process(_ entry: LogEntry) async {
        let acceptedDestinations = destinations.filter { $0.accepts(entry) }

        await withTaskGroup(of: Void.self) { group in
            for destination in acceptedDestinations {
                group.addTask {
                    do {
                        try await destination.write(entry)
                    } catch {
                        Self.writeErrorToStandardError(error, destination: destination)
                    }
                }
            }

            await group.waitForAll()
        }
    }

    nonisolated private static func writeErrorToStandardError(
        _ error: any Error,
        destination: any LogDestination
    ) {
        let destinationType = String(describing: type(of: destination))
        let message = "LoGGer destination write failed in \(destinationType): \(error)\n"

        if let data = message.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}
