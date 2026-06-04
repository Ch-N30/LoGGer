import Foundation
import LoGGer

@main
struct LoGGerDemo {
    static func main() async throws {
        try await demonstrateCompactFormatter()
        try await demonstratePrettyFormatter()
        try await demonstrateKeyValueFormatter()
        try await demonstrateJSONFormatter()
    }

    private static func demonstrateCompactFormatter() async throws {
        printSection("CompactFormatter")

        let logger = logger(
            formatter: CompactFormatter(
                includesLocation: true,
                includesMetadata: true
            )
        )

        logger.info(
            "Tournament summaries loaded",
            category: "Tournaments",
            metadata: ["count": 2]
        )

        try await flushLogPipeline()
    }

    private static func demonstratePrettyFormatter() async throws {
        printSection("PrettyFormatter")

        let tabs = logger(formatter: PrettyFormatter(components: .full))
            .scoped(to: "Tab.Matches")

        tabs.warning(
            "Matches tab tapped",
            metadata: [
                "isReselect": false,
                "previousTab": "tournaments",
                "selectedTab": "matches"
            ]
        )

        try await flushLogPipeline()
    }

    private static func demonstrateKeyValueFormatter() async throws {
        printSection("KeyValueFormatter")

        let network = logger(formatter: KeyValueFormatter())
            .scoped(to: "Network")

        network.error(
            "Failed to decode response",
            metadata: [
                "requestID": "8D4A",
                "status": 500
            ]
        )

        try await flushLogPipeline()
    }

    private static func demonstrateJSONFormatter() async throws {
        printSection("JSONFormatter")

        let auth = logger(formatter: JSONFormatter())
            .scoped(to: "Auth")

        auth.info(
            "Authorization completed",
            metadata: [
                "method": "password",
                "profileID": 42
            ]
        )

        try await flushLogPipeline()
    }

    private static func logger(formatter: any LogFormatter) -> Logger {
        Logger {
            ConsoleDestination(
                formatter: formatter,
                filters: [LevelFilter(.debug)]
            )
        }
    }

    private static func printSection(_ title: String) {
        print("\n=== \(title) ===")
    }

    private static func flushLogPipeline() async throws {
        try await Task.sleep(nanoseconds: 50_000_000)
    }
}
