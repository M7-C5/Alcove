# Apple & Swift Architectural Invariants

This rule governs the architectural patterns, state management, modularization, and modern Swift conventions within Alcove.

---

## 1. Declarative SwiftUI & State Isolation

- **Observation Framework (`@Observable`)**: Use Swift's modern observation framework (`@Observable` class) for view models and observable state. Avoid legacy `ObservableObject` and `@Published` unless interoperating with pre-iOS 17 frameworks.
- **Single Source of Truth**: Keep `@State` private to the view that owns it. Pass `@Bindable` model references or read-only bindings down the view hierarchy.
- **View Body Purity**: Keep `var body: some View` completely free of side effects, disk operations, or asynchronous calls. Use `.task { ... }` or `.onChange` to trigger lifecycle side effects.
- **View Hierarchy Decomposition**: Avoid monolithic view bodies exceeding 80 lines. Extract cohesive sub-components into private subviews or distinct View structs.

---

## 2. Vertical Feature-Slice Modularization

Organize code into clean, modular vertical slices:
- `Core/Models`: Domain models (`Room`, `StageProgress`, `Furniture`, `Layout`).
- `Core/Services`: Service protocols (`MascotAIServiceProtocol`) and implementations.
- `Features/Dashboard`: Room collection grid and scan entry points.
- `Features/Stages`: 4-stage progression cards and stage flow controllers.
- `Features/Studio3D`: RealityKit 3D viewport, Sims-style manipulation, and Mascot HUD.
- `Features/MascotChat`: Mascot conversational drawer and stage evaluation modals.

---

## 3. SwiftData Architecture & Persistence

- **Container Injection**: Rely on SwiftUI's `.modelContainer(for: ...)` established at the root `App` struct.
- **Context Boundaries (`ModelContext`)**:
  - Main thread UI updates must use `@Environment(\.modelContext)` on the `@MainActor`.
  - Heavy background batch operations must instantiate their own `ModelContext(modelContainer)` within background tasks to avoid main-thread UI hitching.
- **Dual Layout Immutability**:
  - `baselineLayout`: Immutable snapshot of the raw scanned room geometry.
  - `workingLayout`: Mutable draft where furniture rearrangement, lighting adjustments, and styling occur.
- **In-Memory Testing Containers**: Provide an in-memory `ModelContainer` (`ModelConfiguration(isStoredInMemoryOnly: true)`) for Swift Testing and SwiftUI Previews to guarantee isolated, sub-second execution without disk side effects.

---

## 4. Swift Concurrency & Thread Safety

- **Actor Isolation**: Annotate view-layer ViewModels and UI mutation functions with `@MainActor`.
- **Async/Await over Callbacks**: Use modern structured concurrency (`async/await`, `TaskGroup`) rather than closure completion handlers.
- **Memory Retention Cycles**: When capturing `self` in escaping closures or observation callbacks, explicitly guard with `[weak self]` to eliminate retain cycles.
- **Sendable Safety**: Ensure domain transfer objects and service payloads conform to `Sendable`.

---

## 5. Modern Swift Testing

- Use Swift Testing (`import Testing`) with `@Suite`, `@Test`, and `#expect(...)` macros for unit test suites in `AlcoveTests`.
