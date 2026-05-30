import Foundation
import LoGGer

@main
struct LoGGerDemo {
    static func main() async throws {
        let logger = Logger {
            ConsoleDestination(
                formatter: PrettyFormatter(components: .full),
                filters: [LevelFilter(.debug)]
            )
        }

        let network = logger.scoped(to: "Network")
        let tabs = logger.scoped(to: "Tab.Matches")

        logger.debug("Application bootstrapped", category: "App")
        try await flushLogPipeline()
        network.info("Request started", metadata: ["path": "/v1/tournaments"])
        try await flushLogPipeline()
        tabs.warning(
            "Matches tab tapped",
            metadata: [
                "isReselect": false,
                "previousTab": "tournaments",
                "selectedTab": "matches"
            ]
        )
        try await flushLogPipeline()
        network.error(
            "Failed to decode response",
            metadata: [
                "requestID": "8D4A",
                "status": 500
            ]
        )

        try await flushLogPipeline()
    }

    private static func flushLogPipeline() async throws {
        try await Task.sleep(nanoseconds: 50_000_000)
    }
}
