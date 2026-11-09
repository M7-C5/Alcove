---
name: perf-audit
description: Superpower skill for measuring Swift compilation time, RealityKit entity memory retain cycles, and SwiftUI view re-render bottlenecks.
---

# Superpower: Swift, RealityKit & Performance Audit

Use this skill when auditing compile speeds, runtime responsiveness, RealityKit entity lifecycles, and memory allocations in Alcove.

## Audit Checklist:

### 1. Swift Compilation Overhead
- **Expression Complexity**: Audit heavily nested closures and untyped dictionary/array literals that strain Swift type inference.
- **Diagnostic Build Flags**: Measure slow function bodies and expressions by adding to compiler arguments:
  ```bash
  -Xfrontend -warn-long-function-bodies=200
  -Xfrontend -warn-long-expression-type-checking=200
  ```
- **View Decomposition**: Decompose massive SwiftUI `var body: some View` implementations into dedicated smaller subviews to keep compile times sub-second.

### 2. RealityKit Entity Lifecycle & Retain Cycles
- **Subscription Retain Cycles**: Check all `scene.subscribe(to: SceneEvents.Update.self)` or gesture event streams for unescaped `self` references. Always capture `[weak self]`.
- **Entity Hierarchy Teardown**: Verify that RealityKit entity graphs and anchor entities are cleanly detached and deallocated when dismissing `Studio3DView` or navigating across stages.
- **Resource Re-use**: Reuse material and texture instances across duplicate furniture entities instead of generating unique procedural allocations per node.

### 3. SwiftUI Redraw & Fast-Path Latency (LP-012)
- **Micro-Reaction Budget**: Ensure the `FastPathRulebook` evaluates furniture clearance and alignment micro-reactions deterministically in $< 100\text{ms}$ on the main thread without blocking on network or remote LLM calls.
- **Observation Granularity**: Keep `@Observable` properties granular so moving a single furniture item does not trigger full-screen re-renders of unrelated HUD panels.
- **Heavy Computation Isolation**: Never execute spatial boundary math, room mesh slicing, or illumination simulations inside SwiftUI `body`. Dispatch to background actors or compute once on mutation.

### 4. Verification Execution Speed & Thermal Footprint
- **Test Isolation**: Keep `AlcoveTests` unit tests headless, in-memory, and sub-second.
- **Thermal Cleanup**: Ensure all background simulators are terminated via `xcrun simctl shutdown all` at the conclusion of every test run.
