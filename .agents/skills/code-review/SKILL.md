---
name: code-review
description: Superpower skill for conducting an adversarial code review on git diffs or proposed Swift/SwiftUI changes before user presentation.
---

# Superpower: Adversarial Code Review (Swift 6 / Apple / RealityKit)

Use this skill to critically review code changes, catch regressions, enforce actor isolation, and guarantee iPad landscape ergonomics before presenting work to the developer.

## Review Checklist:

### 1. Concurrency & Swift 6 Safety
- **Actor Boundaries**: Are all SwiftUI ViewModels, HUD state holders, and UI-bound services annotated with `@MainActor`?
- **Sendable Conformance**: Do data transfer objects, immutable value types, and service protocols crossing async boundaries conform to `Sendable`?
- **Retain Cycles**: Are escaping closures, async tasks, and RealityKit event handlers capturing `self` with `[weak self]` when retain cycles are possible?
- **Unstructured Tasks**: Avoid unmanaged `Task.detached` blocks; ensure tasks inherit or explicitly isolate to `@MainActor`.

### 2. SwiftData & Layout Immutability Discipline
- **Actor Isolation**: Is `ModelContext` accessed and manipulated strictly on its owner actor?
- **Dual Layout Invariant (LP-011)**: Is `baselineLayout` treated as an immutable room scan snapshot? Are user edits, furniture rearrangements, and lighting modifications confined exclusively to `workingLayout`?
- **Relationship Rules**: Are relationships across `Room`, `Layout`, `Furniture`, and `StageProgress` defined with explicit delete rules (`.cascade`, `.nullify`)?

### 3. iPad Landscape Ergonomics & HIG
- **Touch Targets**: Does every interactive element, dial, and Mascot button provide at least $44 \times 44\text{pt}$ hit bounds (preferably $48 \times 48\text{pt}$ for primary HUD controls)?
- **Hit Testing**: Are tappable custom views protected by explicit `.contentShape(Rectangle())`?
- **Native Landscape HUD Layout**: Is the Mascot HUD docked at the bottom-left with adjacent dialogue panel, leaving the 3D room viewport unobstructed?
- **Layout Traps (LP-008)**: Is `.position(x:y:)` avoided in favor of `.offset()` or `ZStack(alignment:)` to prevent unintended greedy frame expansion?
- **Dynamic Type**: Are semantic fonts (`.headline`, `.subheadline`, `.caption`) used instead of hardcoded `.system(size:)`?
- **Color Symmetry**: Are semantic system colors used so views adapt with high contrast across both Light and Dark Modes?

### 4. RealityKit & 3D Spatial Geometry
- **Coordinate Alignment (LP-009)**: Does spatial placement adhere to RealityKit right-handed coordinates ($+X$ right, $+Y$ ceiling/up, $+Z$ towards viewer)?
- **Floor Clamping**: Are furniture entity vertical positions clamped at or above floor level ($Y \ge 0$)?
- **Advisory Evaluation Gate (LP-010)**: Does stage evaluation logic provide a `"Proceed Anyway"` override rather than permanently trapping the user?

### 5. Verification & Testing
- **Swift Testing**: Does every new service or domain logic change include unit tests (`@Suite`, `@Test`, `#expect`) in `AlcoveTests/`?
- **Autonomous Gatekeeper**: Did `./scripts/verify.sh` pass cleanly with zero compiler warnings or errors and automatic thermal cleanup?
