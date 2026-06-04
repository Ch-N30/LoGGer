# LoGGer

```text
$ logger-demo

compact
VERBOSE Auth    Boot cache warmed             14:23:00
DEBUG   Network GET /v1/users                 14:23:01

extended
+----------------------------------------------------------+
| WARNING | Cache   | 14:23:02                             |
+----------------------------------------------------------+
| Disk cache is close to capacity                          |
| -> CacheStore.swift:88                                   |
+----------------------------------------------------------+

error-box
+----------------------------------------------------------+
| ERROR   | Network | 14:23:03                             |
+----------------------------------------------------------+
| Failed to decode response                                |
| -> NetworkService.swift:42                               |
| -> metadata: requestID=8D4A, status=500                  |
+----------------------------------------------------------+
```

![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![Platforms](https://img.shields.io/badge/iOS-16%2B%20%7C%20macOS-13%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)

## Motivation

LoGGer is a small Swift-first logging library with structured filtering, readable terminal formatting, and async delivery. It exists because many loggers hide configuration behind global state or mix core logging with vendor transport concerns.

## Quick Start

```swift
import LoGGer

let logger = Logger {
    ConsoleDestination().withFilter(LevelFilter(.debug))
}

let network = logger.scoped(to: "Network")
network.info("Request started")
network.error("Failed to decode response", metadata: ["status": 500])
```

Run the bundled console demo without creating another project:

```sh
swift run LoGGerDemo
```

## Configuration

Use `LoggerBuilder` to declare destinations and keep filters close to the output they affect.

```swift
let isDevelopment = true

let logger = Logger {
    ConsoleDestination()
        .withFormatter(PrettyFormatter.minimal)
        .withFilter(LevelFilter(.info))

    if isDevelopment {
        ConsoleDestination()
            .withFormatter(PrettyFormatter(components: .full))
            .withFilter(LevelFilter(.debug) && CategoryFilter(["Network", "Auth"]))
    }
}
```

ANSI colors, emoji, and Unicode box-drawing are opt-in. Enable them only for consoles where that output is useful:

```swift
PrettyFormatter(
    components: .full,
    isColorEnabled: true,
    isEmojiEnabled: true,
    usesUnicodeSymbols: true
)
```

## Formatters

- `CompactFormatter` — stable single-line output for Xcode and local debugging.
- `PrettyFormatter` — human-readable compact lines and framed warning/error blocks.
- `KeyValueFormatter` — logfmt-style output for grep-friendly structured logs.
- `JSONFormatter` — machine-readable JSON output for files and external transports.

## Extending

Implement `LogDestination` for custom transports. LoGGer does not ship Sentry or Firebase adapters; keep vendor SDKs in your app or in a separate integration package.

```swift
public protocol SentryReporting: Sendable {
    func capture(
        message: String,
        level: LogLevel,
        metadata: [String: any Sendable]?
    ) async throws
}

public struct SentryDestination: LogDestination {
    public let formatter: any LogFormatter
    public let filters: [any LogFilter]
    private let client: any SentryReporting

    public init(
        client: any SentryReporting,
        formatter: any LogFormatter = PrettyFormatter.minimal,
        filters: [any LogFilter] = [LevelFilter(.error)]
    ) {
        self.client = client
        self.formatter = formatter
        self.filters = filters
    }

    public func write(_ entry: LogEntry) async throws {
        try await client.capture(
            message: formatter.format(entry),
            level: entry.level,
            metadata: entry.metadata
        )
    }
}
```

## Design Goals

- No singleton or hidden process-wide configuration.
- `Sendable` public types for actor-friendly use.
- Async fan-out to multiple destinations.
- Composable filters, formatters, and destinations.
- Lazy message creation when filters can reject an entry first.

## Requirements

- Swift 5.9+
- iOS 16+
- macOS 13+
- Swift Package Manager

## Installation

Add LoGGer as a Swift Package dependency:

```swift
dependencies: [
    .package(url: "https://github.com/Ch-N30/LoGGer.git", branch: "develop")
]
```

Then add the product to your target:

```swift
.target(
    name: "App",
    dependencies: ["LoGGer"]
)
```

Use a tagged version instead of a branch dependency once the repository has a release tag.
