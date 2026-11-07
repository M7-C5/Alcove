# Learned Engineering Patterns

This document records architectural patterns, failure modes, and engineering conventions established across projects. All agents must follow these patterns.

---

### LP-001: Machine-Specific Path Prohibition
- **Rule**: NEVER write machine-specific absolute file paths (e.g. `/Users/...` or `file:///Users/...`) into repository markdown, documentation, scripts, or Swift source files.
- **Remedy**: Always use clean, repository-relative paths (e.g. `docs/ARCHITECTURE.md`, `Alcove/Core/Models/Room.swift`, `scripts/verify.sh`).
- **Why**: Machine-specific paths break portability across team machines, CI/CD runners, and public git repositories.

---

### LP-002: Conventional Commits Specification
- **Rule**: Every git commit message must strictly adhere to the Conventional Commits specification: `<type>(<scope>): <subject>`.
- **Types**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`.
- **Constraint**: Commits must be atomic. Never make monolithic or kitchen-sink commits. Never commit until explicit user approval is granted.

---

### LP-003: Subagent & Verification Delegation
- **Rule**: Research and verification subagents must have clearly bounded scopes. Read-only subagents must not perform writes or execute mutating shell commands.
- **Remedy**: Keep primary orchestration and code changes in the parent agent; delegate deep file scans or independent investigations to subagents.

---

### LP-004: Clean-Slate Architecture
- **Rule**: Do not copy-paste code from previous projects (`Resign`). Build modern, purposeful, idiomatic Swift from scratch.
- **Remedy**: Maintain minimal dependencies, clean modular domain slices, and clear single-responsibility types.

---

### LP-005: Thermal Guard & Simulator Lifecycle
- **Rule**: Automated test runs and background simulators generate intense CPU and memory load.
- **Remedy**: Every test script (`scripts/verify.sh`) MUST end with a cleanup sequence shutting down idle simulators:
  ```bash
  xcrun simctl shutdown all 2>/dev/null || true
  ```

---

### LP-006: iPad Native Landscape HUD Layout
- **Rule**: Alcove is built native landscape-first for iPad.
- **Remedy**: Lock supported interface orientations to Landscape in project configuration. Design HUD overlays with safe area insets and visual novel RPG layout aesthetics (dialogue box docked alongside mascot).

---

### LP-007: SwiftUI Model Propagation & State Traps
- **Rule**: Do not use implicit query containers across deep navigation stacks. Passing `@Bindable` model references directly or scoping views cleanly avoids navigation pop bugs and stale view updates.
- **Remedy**: Store state explicitly in `@Observable` view models or pass direct SwiftData `@Model` references.

---

### LP-008: SwiftUI Layout Expansion (`.position()` Trap)
- **Rule**: Applying `.position(x:y:)` to a SwiftUI view forces the view to consume all available parent space, breaking layout flow and bounds calculations.
- **Remedy**: Use `.offset()`, `Alignment` anchors inside `ZStack`, or explicit `.frame()` sizing to position interactive elements without unintentional layout expansion.

---

### LP-009: RealityKit 3D Coordinate Alignment
- **Rule**: RealityKit uses a right-handed Cartesian coordinate system:
  - $+X$: Right
  - $+Y$: Up (Ceiling)
  - $+Z$: Outwards / Toward viewer
  - $Y=0$: Room floor level.
- **Remedy**: All furniture vertical bounds must sit on or above $Y=0$. Clamp furniture translations within scanned room boundaries ($[-W/2, W/2]$, $[-L/2, L/2]$).

---

### LP-010: Advisory Evaluation Gate with Override
- **Rule**: Gamified progression gates must never permanently block the user if the AI evaluation is overly strict or misinterprets creative intent.
- **Remedy**: Mascot provides detailed bottleneck analysis and recommendations, but always offers a `"Proceed Anyway"` override option to preserve player autonomy.

---

### LP-011: Dual Layout Immutability
- **Rule**: Users must never lose their original scanned room state when experimenting with rearrangements.
- **Remedy**: Maintain two separate layout models:
  - `baselineLayout`: Immutable snapshot of the raw room scan.
  - `workingLayout`: Mutable draft where furniture moves, lighting changes, and color adjustments happen.
  Provides instant "Reset to Original" and powers Stage 4 Before/After split comparison.

---

### LP-012: Fast-Path Rulebook for Micro-Interactivity
- **Rule**: Mascot micro-reactions during furniture movement must respond in under 100ms. Calling remote LLMs on every drag gesture causes lag and network thrashing.
- **Remedy**: Use a local deterministic `FastPathRulebook` (rule-based heuristics) for real-time movement reaction bubbles, and reserve asynchronous LLM calls for full stage evaluation and open chat.

---

### LP-013: Swift 6 Concurrency & Actor Isolation
- **Rule**: Avoid concurrency data races and mutable state leaks.
- **Remedy**: Mark UI view models and services with `@MainActor`. Ensure all data transfer objects conform to `Sendable`.
