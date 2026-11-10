# General Engineering Principles

1. **Sendable & Concurrency Safety**:
   - Mark domain models, geometry helpers, and background services with `Sendable` where appropriate.
   - Guard shared state across actors with `@MainActor` for UI-bound state and isolated actors for background processing.

2. **Nil Safety & Explicit Error Handling**:
   - Never use force-unwrapping (`!`) in production code paths.
   - Prefer `guard let` or `if let` with meaningful logging, safe fallbacks, or typed Swift errors (`throw`).

3. **Value-Type Decoupling**:
   - Prefer immutable `struct` types for spatial calculations, layout configurations, and transient payloads.
   - Confine mutable state strictly to SwiftData `@Model` classes and `@Observable` view models.
