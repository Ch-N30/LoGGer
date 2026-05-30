import XCTest
@testable import LoGGer

final class LoGGerTests: XCTestCase {
    func testLogLevelOrderingFollowsSeverity() {
        XCTAssertLessThan(LogLevel.verbose, .debug)
        XCTAssertLessThan(LogLevel.debug, .info)
        XCTAssertLessThan(LogLevel.info, .warning)
        XCTAssertLessThan(LogLevel.warning, .error)
        XCTAssertLessThan(LogLevel.error, .fault)
    }

    func testLogLevelLabelsAndDescriptions() {
        XCTAssertEqual(LogLevel.verbose.label, "VERBOSE")
        XCTAssertEqual(LogLevel.debug.label, "DEBUG")
        XCTAssertEqual(LogLevel.info.label, "INFO")
        XCTAssertEqual(LogLevel.warning.label, "WARNING")
        XCTAssertEqual(LogLevel.error.label, "ERROR")
        XCTAssertEqual(LogLevel.fault.label, "FAULT")
        XCTAssertEqual(LogLevel.warning.description, "WARNING")
    }

    func testLogLevelTerminalAttributes() {
        XCTAssertEqual(LogLevel.verbose.ansiColor, "\u{001B}[0;37m")
        XCTAssertEqual(LogLevel.debug.ansiColor, "\u{001B}[0;36m")
        XCTAssertEqual(LogLevel.info.ansiColor, "\u{001B}[0;32m")
        XCTAssertEqual(LogLevel.warning.ansiColor, "\u{001B}[0;33m")
        XCTAssertEqual(LogLevel.error.ansiColor, "\u{001B}[0;31m")
        XCTAssertEqual(LogLevel.fault.ansiColor, "\u{001B}[1;35m")
        XCTAssertFalse(LogLevel.error.emoji.isEmpty)
    }

    func testLogEntryStoresProvidedContext() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = LogEntry(
            message: "Request failed",
            level: .error,
            category: "network",
            metadata: ["statusCode": 500, "requestID": "abc"],
            id: id,
            date: date,
            file: "NetworkClient.swift",
            function: "fetch()",
            line: 42
        )

        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.message, "Request failed")
        XCTAssertEqual(entry.level, .error)
        XCTAssertEqual(entry.date, date)
        XCTAssertEqual(String(describing: entry.file), "NetworkClient.swift")
        XCTAssertEqual(String(describing: entry.function), "fetch()")
        XCTAssertEqual(entry.line, 42)
        XCTAssertEqual(entry.category, "network")
        XCTAssertEqual(entry.metadata?["statusCode"] as? Int, 500)
        XCTAssertEqual(entry.metadata?["requestID"] as? String, "abc")
    }

    func testLevelFilterAllowsEntriesAtOrAboveMinimumLevel() {
        let filter = LevelFilter(.warning)

        XCTAssertFalse(filter.isAllowed(makeEntry(level: .info)))
        XCTAssertTrue(filter.isAllowed(makeEntry(level: .warning)))
        XCTAssertTrue(filter.isAllowed(makeEntry(level: .error)))
    }

    func testCategoryFilterAllowsOnlyWhitelistedCategories() {
        let filter = CategoryFilter(["Network", "Auth"])

        XCTAssertTrue(filter.isAllowed(makeEntry(category: "Network")))
        XCTAssertTrue(filter.isAllowed(makeEntry(category: "Auth")))
        XCTAssertFalse(filter.isAllowed(makeEntry(category: "Database")))
        XCTAssertFalse(filter.isAllowed(makeEntry(category: nil)))
    }

    func testBlockFilterUsesPredicate() {
        let filter = BlockFilter { entry in
            entry.message.contains("timeout")
        }

        XCTAssertTrue(filter.isAllowed(makeEntry(message: "Request timeout")))
        XCTAssertFalse(filter.isAllowed(makeEntry(message: "Request failed")))
    }

    func testCompositeFilterAndRequiresAllFiltersToPass() {
        let filter = CompositeFilter(
            [LevelFilter(.debug), CategoryFilter(["Network"])],
            mode: .and
        )

        XCTAssertTrue(filter.isAllowed(makeEntry(level: .error, category: "Network")))
        XCTAssertFalse(filter.isAllowed(makeEntry(level: .verbose, category: "Network")))
        XCTAssertFalse(filter.isAllowed(makeEntry(level: .error, category: "Auth")))
    }

    func testCompositeFilterOrRequiresAtLeastOneFilterToPass() {
        let filter = CompositeFilter(
            [LevelFilter(.fault), CategoryFilter(["Network"])],
            mode: .or
        )

        XCTAssertTrue(filter.isAllowed(makeEntry(level: .fault, category: "Database")))
        XCTAssertTrue(filter.isAllowed(makeEntry(level: .debug, category: "Network")))
        XCTAssertFalse(filter.isAllowed(makeEntry(level: .debug, category: "Database")))
    }

    func testCompositeFilterEmptySemantics() {
        XCTAssertTrue(CompositeFilter([], mode: .and).isAllowed(makeEntry()))
        XCTAssertFalse(CompositeFilter([], mode: .or).isAllowed(makeEntry()))
    }

    func testFilterOperatorsCreateCompositeFilters() {
        let andFilter = LevelFilter(.debug) && CategoryFilter(["Network", "Auth"])
        let orFilter = CategoryFilter(["Network"]) || LevelFilter(.fault)

        XCTAssertTrue(andFilter.isAllowed(makeEntry(level: .info, category: "Network")))
        XCTAssertFalse(andFilter.isAllowed(makeEntry(level: .verbose, category: "Network")))
        XCTAssertFalse(andFilter.isAllowed(makeEntry(level: .info, category: "Database")))

        XCTAssertTrue(orFilter.isAllowed(makeEntry(level: .debug, category: "Network")))
        XCTAssertTrue(orFilter.isAllowed(makeEntry(level: .fault, category: "Database")))
        XCTAssertFalse(orFilter.isAllowed(makeEntry(level: .debug, category: "Database")))
    }

    func testPrettyFormatterComponentsPresets() {
        XCTAssertTrue(PrettyFormatter.Components.minimal.contains(.timestamp))
        XCTAssertTrue(PrettyFormatter.Components.minimal.contains(.category))
        XCTAssertFalse(PrettyFormatter.Components.minimal.contains(.location))

        XCTAssertTrue(PrettyFormatter.Components.full.contains(.timestamp))
        XCTAssertTrue(PrettyFormatter.Components.full.contains(.category))
        XCTAssertTrue(PrettyFormatter.Components.full.contains(.location))
        XCTAssertTrue(PrettyFormatter.Components.full.contains(.threadInfo))
        XCTAssertTrue(PrettyFormatter.Components.full.contains(.metadata))
        XCTAssertTrue(PrettyFormatter.Components.full.contains(.separator))
    }

    func testPrettyFormatterMinimalCompactOutput() {
        let formatter = PrettyFormatter(components: .minimal, timeZoneIdentifier: "UTC")
        let output = formatter.format(
            makeEntry(
                message: "Connected",
                level: .info,
                category: "Network"
            )
        )

        XCTAssertEqual(output, "\u{001B}[0;32mℹ️ INFO Network Connected  22:13:20\u{001B}[0m")
    }

    func testPrettyFormatterFullCompactOutputIncludesOptionalComponents() {
        let formatter = PrettyFormatter(components: .full, timeZoneIdentifier: "UTC")
        let output = formatter.format(
            makeEntry(
                message: "Request finished",
                level: .debug,
                category: "Network",
                metadata: ["requestID": "abc", "statusCode": 200],
                line: 12
            )
        )

        XCTAssertTrue(output.hasPrefix(LogLevel.debug.ansiColor))
        XCTAssertTrue(output.hasSuffix("\u{001B}[0m"))
        XCTAssertTrue(output.contains("🐞 DEBUG Network Request finished"))
        XCTAssertTrue(output.contains("LoGGerTests.swift:12"))
        XCTAssertTrue(output.contains("thread: "))
        XCTAssertTrue(output.contains("requestID=abc, statusCode=200"))
        XCTAssertTrue(output.contains("22:13:20"))
    }

    func testPrettyFormatterExpandedBlockOutput() {
        let formatter = PrettyFormatter(components: .full, timeZoneIdentifier: "UTC")
        let output = formatter.format(
            makeEntry(
                message: "Failed to decode response",
                level: .error,
                category: "Network",
                metadata: ["statusCode": 500],
                file: "NetworkService.swift",
                line: 42
            )
        )

        XCTAssertTrue(output.hasPrefix(LogLevel.error.ansiColor))
        XCTAssertTrue(output.hasSuffix("\u{001B}[0m"))
        XCTAssertTrue(output.contains("╔"))
        XCTAssertTrue(output.contains("╠"))
        XCTAssertTrue(output.contains("╚"))
        XCTAssertTrue(output.contains("❌ ERROR  │  Network  │  22:13:20"))
        XCTAssertTrue(output.contains("Failed to decode response"))
        XCTAssertTrue(output.contains("→ NetworkService.swift:42"))
        XCTAssertTrue(output.contains("→ thread: "))
        XCTAssertTrue(output.contains("→ metadata: statusCode=500"))
    }

    func testPrettyFormatterExpandedBlockWithoutSeparatorComponent() {
        let formatter = PrettyFormatter(
            components: [.timestamp, .category, .location],
            timeZoneIdentifier: "UTC"
        )
        let output = formatter.format(
            makeEntry(
                message: "Warning message",
                level: .warning,
                category: "Auth",
                line: 7
            )
        )

        XCTAssertFalse(output.contains("╠"))
        XCTAssertFalse(output.contains("│"))
        XCTAssertTrue(output.contains("⚠️ WARNING  Auth  22:13:20"))
        XCTAssertTrue(output.contains("→ LoGGerTests.swift:7"))
    }

    func testPrettyFormatterStaticInstances() {
        let entry = makeEntry(message: "Static formatter", level: .info, category: "General")

        XCTAssertTrue(PrettyFormatter.default.format(entry).contains("Static formatter"))
        XCTAssertTrue(PrettyFormatter.minimal.format(entry).contains("Static formatter"))
    }

    func testLogDestinationAcceptsEntryWhenAllFiltersPass() {
        let destination = RecordingDestination(
            filters: [LevelFilter(.warning), CategoryFilter(["Network"])],
            store: RecordingStore()
        )

        XCTAssertTrue(destination.accepts(makeEntry(level: .error, category: "Network")))
        XCTAssertFalse(destination.accepts(makeEntry(level: .info, category: "Network")))
        XCTAssertFalse(destination.accepts(makeEntry(level: .error, category: "Auth")))
    }

    func testLogDestinationWithoutFiltersAcceptsEveryEntry() {
        let destination = RecordingDestination(store: RecordingStore())

        XCTAssertTrue(destination.accepts(makeEntry(level: .verbose, category: nil)))
    }

    func testLogActorProcessesOnlyAcceptedDestinations() async {
        let networkStore = RecordingStore()
        let authStore = RecordingStore()
        let logger = LogActor(
            destinations: [
                RecordingDestination(filters: [CategoryFilter(["Network"])], store: networkStore),
                RecordingDestination(filters: [CategoryFilter(["Auth"])], store: authStore)
            ]
        )

        await logger.process(makeEntry(message: "Network response", level: .info, category: "Network"))

        let networkMessages = await networkStore.messages()
        let authMessages = await authStore.messages()

        XCTAssertEqual(networkMessages, ["Network response"])
        XCTAssertEqual(authMessages, [])
    }

    func testLogActorContinuesWhenDestinationThrows() async {
        let store = RecordingStore()
        let logger = LogActor(
            destinations: [
                RecordingDestination(store: RecordingStore(), writeError: TestWriteError.failed),
                RecordingDestination(store: store)
            ]
        )

        await logger.process(makeEntry(message: "Still written", level: .error))

        let messages = await store.messages()

        XCTAssertEqual(messages, ["Still written"])
    }

    private func makeEntry(
        message: String = "Message",
        level: LogLevel = .info,
        category: String? = "General",
        metadata: [String: any Sendable]? = nil,
        file: StaticString = "LoGGerTests.swift",
        line: UInt = 1
    ) -> LogEntry {
        LogEntry(
            message: message,
            level: level,
            category: category,
            metadata: metadata,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            file: file,
            function: "makeEntry()",
            line: line
        )
    }
}

private actor RecordingStore {
    private var entries: [LogEntry] = []

    func append(_ entry: LogEntry) {
        entries.append(entry)
    }

    func messages() -> [String] {
        entries.map(\.message)
    }
}

private final class RecordingDestination: LogDestination {
    let formatter: any LogFormatter
    let filters: [any LogFilter]

    private let store: RecordingStore
    private let writeError: (any Error)?

    init(
        formatter: any LogFormatter = PrettyFormatter.minimal,
        filters: [any LogFilter] = [],
        store: RecordingStore,
        writeError: (any Error)? = nil
    ) {
        self.formatter = formatter
        self.filters = filters
        self.store = store
        self.writeError = writeError
    }

    func write(_ entry: LogEntry) async throws {
        if let writeError {
            throw writeError
        }

        await store.append(entry)
    }
}

private enum TestWriteError: Error {
    case failed
}
