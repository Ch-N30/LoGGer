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

    private func makeEntry(
        message: String = "Message",
        level: LogLevel = .info,
        category: String? = "General"
    ) -> LogEntry {
        LogEntry(
            message: message,
            level: level,
            category: category,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            file: "LoGGerTests.swift",
            function: "makeEntry()",
            line: 1
        )
    }
}
