/// A rule that decides whether a log entry should pass through a logging pipeline.
///
/// Filters are value-oriented and `Sendable`, so they can be safely passed across actor boundaries.
///
/// Example:
/// ```swift
/// let filter = LevelFilter(.debug)
/// let isVisible = filter.isAllowed(entry)
/// ```
public protocol LogFilter: Sendable {
    /// Returns whether the specified entry is allowed by this filter.
    ///
    /// - Parameter entry: The log entry to evaluate.
    /// - Returns: `true` when the entry should pass through; otherwise, `false`.
    func isAllowed(_ entry: LogEntry) -> Bool
}

/// A filter that allows entries whose severity is greater than or equal to a minimum level.
///
/// Example:
/// ```swift
/// let filter = LevelFilter(.warning)
/// filter.isAllowed(errorEntry) // true
/// filter.isAllowed(debugEntry) // false
/// ```
public struct LevelFilter: LogFilter {
    /// The minimum severity level allowed by the filter.
    public let minLevel: LogLevel

    /// Creates a filter that allows entries at or above the specified severity level.
    ///
    /// - Parameter minLevel: The minimum severity level to allow.
    public init(_ minLevel: LogLevel) {
        self.minLevel = minLevel
    }

    /// Returns whether the entry's level is greater than or equal to `minLevel`.
    ///
    /// - Parameter entry: The log entry to evaluate.
    /// - Returns: `true` when `entry.level >= minLevel`; otherwise, `false`.
    public func isAllowed(_ entry: LogEntry) -> Bool {
        entry.level >= minLevel
    }
}

/// A filter that allows entries whose category is included in a whitelist.
///
/// Entries without a category are rejected.
///
/// Example:
/// ```swift
/// let filter = CategoryFilter(["Network", "Auth"])
/// filter.isAllowed(networkEntry) // true
/// filter.isAllowed(databaseEntry) // false
/// ```
public struct CategoryFilter: LogFilter {
    /// The whitelisted categories allowed by the filter.
    public let categories: [String]

    private let categorySet: Set<String>

    /// Creates a filter that allows only entries matching the specified categories.
    ///
    /// - Parameter categories: The whitelisted categories to allow.
    public init(_ categories: [String]) {
        self.categories = categories
        self.categorySet = Set(categories)
    }

    /// Returns whether the entry's category is present in `categories`.
    ///
    /// - Parameter entry: The log entry to evaluate.
    /// - Returns: `true` when `entry.category` is whitelisted; otherwise, `false`.
    public func isAllowed(_ entry: LogEntry) -> Bool {
        guard let category = entry.category else {
            return false
        }

        return categorySet.contains(category)
    }
}

/// A filter backed by a caller-provided `@Sendable` closure.
///
/// Use this type for rules that are too specific to justify a dedicated filter type.
///
/// Example:
/// ```swift
/// let filter = BlockFilter { entry in
///     entry.message.contains("timeout")
/// }
/// ```
public struct BlockFilter: LogFilter {
    private let predicate: @Sendable (LogEntry) -> Bool

    /// Creates a filter that evaluates entries with the specified closure.
    ///
    /// - Parameter predicate: A `@Sendable` closure that returns whether an entry is allowed.
    public init(_ predicate: @escaping @Sendable (LogEntry) -> Bool) {
        self.predicate = predicate
    }

    /// Returns the result of evaluating the entry with the stored predicate.
    ///
    /// - Parameter entry: The log entry to evaluate.
    /// - Returns: `true` when the stored predicate allows the entry; otherwise, `false`.
    public func isAllowed(_ entry: LogEntry) -> Bool {
        predicate(entry)
    }
}

/// A filter that combines multiple filters using Boolean logic.
///
/// Example:
/// ```swift
/// let filter = CompositeFilter(
///     [LevelFilter(.debug), CategoryFilter(["Network", "Auth"])],
///     mode: .and
/// )
/// ```
public struct CompositeFilter: LogFilter {
    /// A Boolean mode used to combine child filters.
    public enum Mode: Sendable {
        /// Allows an entry only when every child filter allows it.
        case and

        /// Allows an entry when at least one child filter allows it.
        case or
    }

    /// The child filters evaluated by this composite filter.
    public let filters: [any LogFilter]

    /// The Boolean mode used to combine child filter results.
    public let mode: Mode

    /// Creates a composite filter from child filters and a Boolean mode.
    ///
    /// Empty `.and` filters allow every entry, matching `allSatisfy` semantics.
    /// Empty `.or` filters reject every entry, matching `contains` semantics.
    ///
    /// - Parameters:
    ///   - filters: The child filters to combine.
    ///   - mode: The Boolean mode used to combine child filter results.
    public init(_ filters: [any LogFilter], mode: Mode) {
        self.filters = filters
        self.mode = mode
    }

    /// Returns whether the entry is allowed by the composed child filters.
    ///
    /// - Parameter entry: The log entry to evaluate.
    /// - Returns: The combined child filter result for the configured `mode`.
    public func isAllowed(_ entry: LogEntry) -> Bool {
        switch mode {
        case .and:
            return filters.allSatisfy { $0.isAllowed(entry) }
        case .or:
            return filters.contains { $0.isAllowed(entry) }
        }
    }
}

/// Creates an `AND` composite filter from two filters.
///
/// Example:
/// ```swift
/// let filter = LevelFilter(.debug) && CategoryFilter(["Network", "Auth"])
/// ```
///
/// - Parameters:
///   - lhs: The left-hand filter.
///   - rhs: The right-hand filter.
/// - Returns: A composite filter that allows entries only when both filters allow them.
public func && <Left: LogFilter, Right: LogFilter>(
    lhs: Left,
    rhs: @autoclosure () -> Right
) -> CompositeFilter {
    CompositeFilter([lhs, rhs()], mode: .and)
}

/// Creates an `OR` composite filter from two filters.
///
/// Example:
/// ```swift
/// let filter = CategoryFilter(["Network"]) || LevelFilter(.fault)
/// ```
///
/// - Parameters:
///   - lhs: The left-hand filter.
///   - rhs: The right-hand filter.
/// - Returns: A composite filter that allows entries when at least one filter allows them.
public func || <Left: LogFilter, Right: LogFilter>(
    lhs: Left,
    rhs: @autoclosure () -> Right
) -> CompositeFilter {
    CompositeFilter([lhs, rhs()], mode: .or)
}
