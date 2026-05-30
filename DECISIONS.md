# Architecture Decisions

This document records the main design decisions behind the logging library. These choices are not treated as permanent doctrine. They describe the current scope and the trade-offs accepted for this package.

## 1. Actor Instead of DispatchQueue

### Context

The logger needs to coordinate asynchronous writes to multiple destinations. Each destination can have its own filters, formatter, and write latency. A traditional implementation could use a private `DispatchQueue` to serialize access and fan out work.

That approach works, but it is outside the type system. The compiler cannot prove much about isolation, and it is easy to accidentally capture mutable state across queue hops.

### Decision

The package uses `LogActor` as the async core. Actor isolation matches the Swift Concurrency model used by the public API and keeps coordination state protected by the language instead of by convention.

Inside `LogActor.process(_:)`, matching destinations are written to concurrently through a task group. The actor owns the coordination step, while individual destination writes can proceed independently.

### Trade-offs

Actors are safer for shared mutable state, but they introduce an async boundary. Callers do not get immediate synchronous completion of the write pipeline.

Actor-based code also depends on Swift Concurrency availability and its runtime behavior. This is acceptable for a Swift 5.9+ package, but it is still a constraint compared with a pure `DispatchQueue` implementation.

The actor is not chosen because it is always faster. It is chosen because the isolation model is explicit, compiler-checked, and harder to misuse.

## 2. Protocols Instead of Concrete Types

### Context

Logging has several extension points: filters, formatters, and destinations. Tests also need to observe writes without depending on terminal output or real infrastructure.

`MockDestination` exists specifically because destinations are modeled behind `LogDestination`. It can capture `LogEntry` values, count writes, and simulate latency without changing production code.

### Decision

The package exposes `LogFilter`, `LogFormatter`, and `LogDestination` protocols. `Logger` stores destinations as `[any LogDestination]`.

Existentials are used instead of making `Logger` generic over a destination type because a real logger usually has heterogeneous destinations: console output, test capture, file output, remote transport, or custom integrations. A generic `Logger<Destination>` would make that composition awkward and would leak implementation details into the public API.

### Trade-offs

Using `any LogDestination` has runtime dispatch cost and loses some static specialization that generics could provide. It also means some mistakes are discovered through behavior and tests rather than purely through generic constraints.

The trade-off is intentional. The public API stays stable and ergonomic, and callers can compose different destination implementations in one logger instance.

## 3. No Singleton

### Context

Logging libraries often expose a global `Logger.shared`. That is convenient at first, but it creates hidden dependencies. Code that appears pure can silently depend on process-wide logging state.

This becomes expensive in tests. Test order can start to matter, global configuration can leak between cases, and replacing real destinations with mocks requires additional reset hooks or unsafe mutation.

### Decision

The package does not provide a singleton. `Logger` is created explicitly and passed where it is needed.

Dependency injection keeps ownership visible. Production code can configure real destinations, while tests can inject a logger backed by `MockDestination` or any other controlled destination.

### Trade-offs

The caller has to decide where the logger lives and how it is passed through the application. That is more setup than calling a global static instance.

The benefit is that dependencies remain visible, tests stay isolated, and multiple logger configurations can coexist without shared mutable global state.

## 4. `@resultBuilder` for Configuration

### Context

Logger configuration is naturally a list of destinations, often with conditional entries. A plain array would work, and a fluent API could also work.

The array form is mechanically simple but gets noisy once conditional destinations are involved. A fluent API can become readable for one object, but it tends to hide whether configuration is mutating, copying, or accumulating state.

### Decision

The package uses `LoggerBuilder` so configuration can be written as a block:

```swift
let logger = Logger {
    ConsoleDestination()

    if isDevelopment {
        ConsoleDestination()
            .withFormatter(PrettyFormatter(components: .full))
            .withFilter(LevelFilter(.verbose))
    }
}
```

The builder supports blocks, arrays, and optional branches so conditional configuration remains readable.

### Trade-offs

Result builders add compiler magic. Error messages can be less obvious than with a plain array, and the implementation requires extra builder entry points such as `buildBlock`, `buildArray`, and `buildOptional`.

The trade-off is acceptable because logger setup is usually read more often than it is edited, and the builder keeps the destination structure clear at the call site.

## 5. `@autoclosure` for `message`

### Context

Log messages often include string interpolation, JSON encoding, debug dumps, or other work that is only useful if the entry is actually written.

For example, a debug log might include a large decoded response:

```swift
logger.debug("Response payload: \(expensivePrettyPrintedJSON(payload))")
```

If every configured destination rejects `.debug` entries in production, building that string is wasted work.

### Decision

The main logging methods accept `message` as `@autoclosure`. This lets the logger delay string construction until it knows the message is needed.

The implementation can preflight filters that are independent of the final message, such as level and category filters. If those filters reject the entry, the message closure is never evaluated.

### Trade-offs

`@autoclosure` can hide work and side effects. Callers should treat log message expressions as pure formatting code and avoid mutating state inside them.

There is also a correctness limit: `BlockFilter` receives a full `LogEntry`, so it may inspect `entry.message`. In that case the logger cannot safely skip message evaluation without changing filter semantics. Lazy evaluation is therefore strongest for message-independent filters, not for arbitrary custom predicates.

## 6. Intentionally Out of Scope

### Context

Several features are useful in real products but are not part of this core package: a file appender, ready-made Sentry or Firebase integrations, and JSON-based runtime configuration.

Adding them directly would make the library broader, but not necessarily better. Each one brings policy decisions that belong to the host application or to a separate adapter package.

### Decision

The core package stays focused on log levels, entries, filters, formatting, destinations, and async dispatch.

A file appender is intentionally excluded because it involves persistence policy: file rotation, retention, disk pressure, file protection, background writes, and platform-specific storage rules.

Sentry and Firebase integrations are intentionally excluded because they add vendor SDK dependencies, privacy decisions, network retry behavior, batching policy, and dependency version constraints.

JSON configuration is intentionally excluded because it requires a schema, validation, migration rules, dynamic reload behavior, and security boundaries around externally supplied configuration.

### Trade-offs

The package is less turnkey. Applications that need persistence, vendor transport, or remote configuration must provide those pieces themselves.

The benefit is a smaller core with fewer dependencies and fewer hidden product decisions. Those features can still be built as `LogDestination`, `LogFilter`, or configuration adapters outside the core library.
