import Foundation
import Testing
@testable import LoGGer

@Suite("LoGGer")
struct LoGGerTests {
    @Test("Filtering drops entries below minimum level")
    func filteringDropsEntriesBelowMinimumLevel() async throws {
        // Given
        let destination = MockDestination(filters: [LevelFilter(.error)])
        let logger = Logger {
            destination
        }
        var messageEvaluationCount = 0

        func makeMessage() -> String {
            messageEvaluationCount += 1
            return "Debug details"
        }

        // When
        logger.debug(makeMessage())
        try await Task.sleep(for: .milliseconds(20))

        // Then
        #expect(destination.captured.isEmpty)
        #expect(destination.writeCallCount == 0)
        #expect(messageEvaluationCount == 0)
    }

    @Test("CategoryFilter whitelist allows only configured categories")
    func categoryFilterWhitelistAllowsOnlyConfiguredCategories() async {
        // Given
        let destination = MockDestination(filters: [CategoryFilter(["Network", "Auth"])])
        let logger = Logger {
            destination
        }

        // When
        logger.info("Network connected", category: "Network")
        logger.info("Auth refreshed", category: "Auth")
        logger.info("Database opened", category: "Database")
        logger.info("Uncategorized")
        let captured = await waitForEntries(in: destination, expectedCount: 2)

        // Then
        #expect(Set(captured.map(\.message)) == Set(["Network connected", "Auth refreshed"]))
        #expect(Set(captured.compactMap(\.category)) == Set(["Network", "Auth"]))
        #expect(destination.writeCallCount == 2)
    }

    @Test("CompositeFilter supports AND and OR logic")
    func compositeFilterSupportsAndAndOrLogic() {
        // Given
        let andFilter = LevelFilter(.warning) && CategoryFilter(["Network"])
        let orFilter = CategoryFilter(["Network"]) || LevelFilter(.fault)

        // When
        let warningNetwork = makeEntry(level: .warning, category: "Network")
        let infoNetwork = makeEntry(level: .info, category: "Network")
        let faultDatabase = makeEntry(level: .fault, category: "Database")
        let debugDatabase = makeEntry(level: .debug, category: "Database")

        // Then
        #expect(andFilter.isAllowed(warningNetwork))
        #expect(!andFilter.isAllowed(infoNetwork))
        #expect(orFilter.isAllowed(infoNetwork))
        #expect(orFilter.isAllowed(faultDatabase))
        #expect(!orFilter.isAllowed(debugDatabase))
    }

    @Test("Multiple destinations each receive the entry")
    func multipleDestinationsEachReceiveEntry() async throws {
        // Given
        let firstDestination = MockDestination()
        let secondDestination = MockDestination()
        let logger = Logger {
            firstDestination
            secondDestination
        }

        // When
        logger.warning("Fan-out", category: "System")
        let firstEntries = await waitForEntries(in: firstDestination, expectedCount: 1)
        let secondEntries = await waitForEntries(in: secondDestination, expectedCount: 1)

        // Then
        let firstEntry = try #require(firstEntries.first)
        let secondEntry = try #require(secondEntries.first)
        #expect(firstEntry.message == "Fan-out")
        #expect(secondEntry.message == "Fan-out")
        #expect(firstEntry.id == secondEntry.id)
        #expect(firstDestination.writeCallCount == 1)
        #expect(secondDestination.writeCallCount == 1)
    }

    @Test("log() does not block caller while destination writes asynchronously")
    func logDoesNotBlockCallerWhileDestinationWritesAsynchronously() async {
        // Given
        let destination = MockDestination(sleepDuration: .milliseconds(250))
        let logger = Logger {
            destination
        }
        let clock = ContinuousClock()

        // When
        let elapsed = clock.measure {
            logger.info("Delayed destination")
        }
        let captured = await waitForEntries(in: destination, expectedCount: 1)

        // Then
        #expect(elapsed < .milliseconds(50))
        #expect(captured.map(\.message) == ["Delayed destination"])
        #expect(destination.writeCallCount == 1)
    }

    @Test("ScopedLogger applies category automatically")
    func scopedLoggerAppliesCategoryAutomatically() async {
        // Given
        let destination = MockDestination(filters: [CategoryFilter(["Network"])])
        let logger = Logger {
            destination
        }
        let scopedLogger = logger.scoped(to: "Network")

        // When
        scopedLogger.error("Request failed")
        let captured = await waitForEntries(in: destination, expectedCount: 1)

        // Then
        #expect(captured.first?.message == "Request failed")
        #expect(captured.first?.category == "Network")
        #expect(destination.writeCallCount == 1)
    }

    @Test("Logger can be used through iLog abstraction")
    func loggerCanBeUsedThroughILogAbstraction() async {
        // Given
        let destination = MockDestination()
        let logger: any iLog = Logger {
            destination
        }

        // When
        logger.info("Injected logger", category: "DI")
        let captured = await waitForEntries(in: destination, expectedCount: 1)

        // Then
        #expect(captured.first?.message == "Injected logger")
        #expect(captured.first?.category == "DI")
        #expect(destination.writeCallCount == 1)
    }

    @Test("ScopedLogger can be used through iLog abstraction")
    func scopedLoggerCanBeUsedThroughILogAbstraction() async {
        // Given
        let destination = MockDestination(filters: [CategoryFilter(["Network"])])
        let logger = Logger {
            destination
        }
        let scopedLogger: any iLog = logger.scoped(to: "Network")

        // When
        scopedLogger.info("Scoped protocol logger")
        let captured = await waitForEntries(in: destination, expectedCount: 1)

        // Then
        #expect(captured.first?.message == "Scoped protocol logger")
        #expect(captured.first?.category == "Network")
        #expect(destination.writeCallCount == 1)
    }

    @Test("NoOpLogger drops messages without evaluating them")
    func noOpLoggerDropsMessagesWithoutEvaluatingThem() {
        // Given
        let logger: any iLog = NoOpLogger()
        var messageEvaluationCount = 0

        func makeMessage() -> String {
            messageEvaluationCount += 1
            return "Expensive no-op message"
        }

        // When
        logger.debug(makeMessage())
        logger.error(makeMessage(), category: "Network", metadata: ["status": 500])

        // Then
        #expect(messageEvaluationCount == 0)
    }

    @Test("NoOpLogger scoped logger remains no-op")
    func noOpLoggerScopedLoggerRemainsNoOp() {
        // Given
        let logger: any iLog = NoOpLogger().scoped(to: "Network")
        var messageEvaluationCount = 0

        func makeMessage() -> String {
            messageEvaluationCount += 1
            return "Expensive scoped no-op message"
        }

        // When
        logger.warning(makeMessage())

        // Then
        #expect(messageEvaluationCount == 0)
    }

    @Test("@autoclosure message is not evaluated when filtered out")
    func autoclosureMessageIsNotEvaluatedWhenFilteredOut() async throws {
        // Given
        let destination = MockDestination(filters: [LevelFilter(.fault)])
        let logger = Logger {
            destination
        }
        var messageEvaluationCount = 0

        func makeMessage() -> String {
            messageEvaluationCount += 1
            return "Expensive message"
        }

        // When
        logger.error(makeMessage())
        try await Task.sleep(for: .milliseconds(20))

        // Then
        #expect(messageEvaluationCount == 0)
        #expect(destination.captured.isEmpty)
        #expect(destination.writeCallCount == 0)
    }

    @Test("@autoclosure message stays lazy through iLog abstraction")
    func autoclosureMessageStaysLazyThroughILogAbstraction() async throws {
        // Given
        let destination = MockDestination(filters: [LevelFilter(.fault)])
        let logger: any iLog = Logger {
            destination
        }
        var messageEvaluationCount = 0

        func makeMessage() -> String {
            messageEvaluationCount += 1
            return "Expensive protocol message"
        }

        // When
        logger.error(makeMessage())
        try await Task.sleep(for: .milliseconds(20))

        // Then
        #expect(messageEvaluationCount == 0)
        #expect(destination.captured.isEmpty)
        #expect(destination.writeCallCount == 0)
    }

    @Test("PrettyFormatter output contains expected components")
    func prettyFormatterOutputContainsExpectedComponents() {
        // Given
        let formatter = PrettyFormatter(
            components: .full,
            timeZoneIdentifier: "UTC",
            isColorEnabled: true,
            usesUnicodeSymbols: true
        )
        let entry = makeEntry(
            message: "Failed to decode response",
            level: .error,
            category: "Network",
            metadata: ["statusCode": 500],
            file: "NetworkService.swift",
            line: 42
        )

        // When
        let output = formatter.format(entry)

        // Then
        #expect(output.hasPrefix(LogLevel.error.ansiColor))
        #expect(output.hasSuffix("\u{001B}[0m"))
        #expect(output.contains("ERROR"))
        #expect(output.contains("Network"))
        #expect(output.contains("22:13:20"))
        #expect(output.contains("Failed to decode response"))
        #expect(output.contains("NetworkService.swift:42"))
        #expect(output.contains("statusCode=500"))
        #expect(output.contains("╔"))
        #expect(output.contains("╚"))
    }

    @Test("PrettyFormatter does not emit ANSI colors by default")
    func prettyFormatterDoesNotEmitAnsiColorsByDefault() {
        // Given
        let formatter = PrettyFormatter(components: .full, timeZoneIdentifier: "UTC")
        let entry = makeEntry(level: .debug)

        // When
        let output = formatter.format(entry)

        // Then
        #expect(!output.contains("\u{001B}"))
        #expect(!output.contains("[0;36m"))
        #expect(!output.contains("[0m"))
    }

    @Test("PrettyFormatter keeps low severity entries compact")
    func prettyFormatterKeepsLowSeverityEntriesCompact() {
        // Given
        let formatter = PrettyFormatter(components: .full, timeZoneIdentifier: "UTC")
        let entry = makeEntry(
            message: "Tournament summaries loaded",
            level: .debug,
            category: "Tournaments",
            metadata: ["count": 2],
            file: "TournamentListViewModel.swift",
            line: 23
        )

        // When
        let output = formatter.format(entry)

        // Then
        #expect(!output.contains("\n"))
        #expect(output.contains("DEBUG Tournaments Tournament summaries loaded"))
        #expect(!output.contains("🐞"))
        #expect(output.contains("22:13:20"))
        #expect(!output.contains("TournamentListViewModel.swift:23"))
        #expect(!output.contains("thread:"))
        #expect(!output.contains("count=2"))
    }

    @Test("PrettyFormatter emits emoji only when enabled")
    func prettyFormatterEmitsEmojiOnlyWhenEnabled() {
        // Given
        let plainFormatter = PrettyFormatter(components: .minimal, timeZoneIdentifier: "UTC")
        let emojiFormatter = PrettyFormatter(
            components: .minimal,
            timeZoneIdentifier: "UTC",
            isEmojiEnabled: true
        )
        let entry = makeEntry(level: .info)

        // When
        let plainOutput = plainFormatter.format(entry)
        let emojiOutput = emojiFormatter.format(entry)

        // Then
        #expect(!plainOutput.contains(LogLevel.info.emoji))
        #expect(emojiOutput.contains(LogLevel.info.emoji))
    }

    @Test("PrettyFormatter uses Xcode-safe ASCII symbols by default")
    func prettyFormatterUsesXcodeSafeAsciiSymbolsByDefault() {
        // Given
        let formatter = PrettyFormatter(components: .full, timeZoneIdentifier: "UTC")
        let entry = makeEntry(
            message: "Matches tab tapped",
            level: .warning,
            category: "Tab.Matches",
            metadata: [
                "isReselect": false,
                "previousTab": "tournaments",
                "selectedTab": "matches"
            ],
            file: "MainTabScreen.swift",
            line: 77
        )

        // When
        let output = formatter.format(entry)

        // Then
        #expect(output.contains("+---"))
        #expect(output.contains("WARNING | Tab.Matches | 22:13:20"))
        #expect(output.contains("-> MainTabScreen.swift:77"))
        #expect(output.contains("-> metadata:"))
        #expect(output.contains("   isReselect=false"))
        #expect(!output.contains("╔"))
        #expect(!output.contains("║"))
        #expect(!output.contains("⚠️"))
    }

    @Test("CompactFormatter renders plain single-line output")
    func compactFormatterRendersPlainSingleLineOutput() {
        // Given
        let formatter = CompactFormatter(
            includesLocation: true,
            includesMetadata: true,
            timeZoneIdentifier: "UTC"
        )
        let entry = makeEntry(
            message: "Tournament summaries loaded",
            level: .debug,
            category: "Tournaments",
            metadata: ["count": 2],
            file: "TournamentListViewModel.swift",
            line: 23
        )

        // When
        let output = formatter.format(entry)

        // Then
        #expect(output == "DEBUG Tournaments Tournament summaries loaded TournamentListViewModel.swift:23 count=2  22:13:20")
    }

    @Test("KeyValueFormatter renders logfmt-style output")
    func keyValueFormatterRendersLogfmtStyleOutput() {
        // Given
        let formatter = KeyValueFormatter(timeZoneIdentifier: "UTC")
        let entry = makeEntry(
            message: "Failed to decode response",
            level: .error,
            category: "Network",
            metadata: ["status": 500],
            file: "NetworkService.swift",
            line: 42
        )

        // When
        let output = formatter.format(entry)

        // Then
        #expect(output.contains("level=ERROR"))
        #expect(output.contains("category=Network"))
        #expect(output.contains("message=\"Failed to decode response\""))
        #expect(output.contains("file=NetworkService.swift"))
        #expect(output.contains("line=42"))
        #expect(output.contains("status=500"))
    }

    @Test("JSONFormatter renders parseable JSON output")
    func jsonFormatterRendersParseableJsonOutput() throws {
        // Given
        let formatter = JSONFormatter(timeZoneIdentifier: "UTC")
        let entry = makeEntry(
            message: "Failed to decode response",
            level: .error,
            category: "Network",
            metadata: ["status": 500],
            file: "NetworkService.swift",
            line: 42
        )

        // When
        let output = formatter.format(entry)
        let data = try #require(output.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let metadata = try #require(object["metadata"] as? [String: Any])

        // Then
        #expect(object["level"] as? String == "ERROR")
        #expect(object["category"] as? String == "Network")
        #expect(object["message"] as? String == "Failed to decode response")
        #expect(object["file"] as? String == "NetworkService.swift")
        #expect(object["line"] as? Int == 42)
        #expect(metadata["status"] as? Int == 500)
    }

    private func waitForEntries(
        in destination: MockDestination,
        expectedCount: Int
    ) async -> [LogEntry] {
        for _ in 0..<50 {
            let entries = destination.captured
            if entries.count == expectedCount {
                return entries
            }

            try? await Task.sleep(for: .milliseconds(10))
        }

        return destination.captured
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

private final class MockDestination: LogDestination, @unchecked Sendable {
    let formatter: any LogFormatter
    let filters: [any LogFilter]
    let sleepDuration: Duration

    var captured: [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return capturedStorage
    }

    var writeCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return writeCallCountStorage
    }

    private let lock = NSLock()
    private var capturedStorage: [LogEntry] = []
    private var writeCallCountStorage = 0

    init(
        formatter: any LogFormatter = PrettyFormatter.minimal,
        filters: [any LogFilter] = [],
        sleepDuration: Duration = .zero
    ) {
        self.formatter = formatter
        self.filters = filters
        self.sleepDuration = sleepDuration
    }

    func write(_ entry: LogEntry) async throws {
        if sleepDuration != .zero {
            try await Task.sleep(for: sleepDuration)
        }

        record(entry)
    }

    private func record(_ entry: LogEntry) {
        lock.lock()
        defer { lock.unlock() }
        capturedStorage.append(entry)
        writeCallCountStorage += 1
    }
}
