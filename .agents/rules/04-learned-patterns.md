# Living Post-Mortem & Empirical Patterns Ledger

> **Purpose**: Captures empirical SwiftUI, SwiftData, RealityKit, and Xcode traps specific to Alcove.
> **Loading Invariant**: Consult this ledger before modifying spatial, persistence, or Xcode project code.

---

## Learned Patterns Index

| ID | Category | Title | Heuristic Summary |
| :--- | :--- | :--- | :--- |
| **LP-007** | SwiftUI | Model Propagation & State Traps | Avoid dynamic `@Query` inside navigation destinations; pass direct `@Bindable` model references. |
| **LP-008** | SwiftUI | Layout Expansion (`.position()` Trap) | `.position(x:y:)` greedily fills parent frame; use `.offset()` or `ZStack` alignment anchors instead. |
| **LP-009** | RealityKit | 3D Coordinate Alignment | Right-handed coordinates ($+X$ right, $+Y$ up, $+Z$ towards viewer); floor at $Y=0$, clamp within bounds. |
| **LP-010** | UX / Curriculum | Advisory Evaluation Gate with Override | Never permanently trap users on subjective gates; always provide a `"Proceed Anyway"` override. |
| **LP-011** | SwiftData | Dual Layout Immutability | Preserve scanned room state in immutable `baselineLayout`; apply all user edits to `workingLayout`. |
| **LP-012** | Performance | Fast-Path Rulebook for Micro-Interactivity | Real-time drag reactions must execute in `<100ms` via local heuristics; reserve LLMs for chat & stage gates. |
| **LP-015** | Spatial RoomPlan | Wall Thickness Drywall Bounding Box Trap | Outer bounds include wall prism thickness; offset furniture bounds by wall half-thickness to prevent wall clipping. |
| **LP-016** | RealityKit | Cutaway Wall Shadow Pass Trap | `entity.isEnabled = false` removes walls from the directional shadow depth pass; use `OpacityComponent(opacity: 0.0)` on iOS 18+ to hide walls while preserving shadows. |
| **LP-017** | Xcode / Git | Synced Project & Signing Discipline | `project.xcproj` auto-syncs folders; never commit local `DEVELOPMENT_TEAM` or `PRODUCT_BUNDLE_IDENTIFIER` overrides. |

---

## Detailed Heuristic Profiles

### LP-007: Model Propagation & State Traps
* **Problem**: Using `@Query` inside child navigation views causes SwiftData crashes or stale fetches when navigating across rooms.
* **Rule**: Pass `@Bindable var room: Room` directly from the parent container down the navigation stack.

### LP-008: Layout Expansion (`.position()` Trap)
* **Problem**: `.position(x:y:)` expands the frame to fill its parent, stealing touches from the 3D viewport underneath.
* **Rule**: Use `ZStack(alignment:)` with `.padding()` or `.offset()` for floating HUD overlays.

### LP-009: 3D Coordinate Alignment
* **Rule**: Adhere strictly to RealityKit's right-handed coordinate space (`+X` right, `+Y` up, `+Z` toward viewer). Clamp `positionY >= 0` and keep `(positionX, positionZ)` inside room half-extents minus furniture half-sizes.

### LP-010: Advisory Evaluation Gate with Override
* **Rule**: Stage evaluations must inform and guide the user while always offering a `"Proceed Anyway"` override so edge-case room layouts never permanently lock progression.

### LP-011: Dual Layout Immutability
* **Rule**: Never mutate `room.baselineLayout` after initial creation. All rearrangement, archiving, and lighting fixture edits target `room.workingLayout` (or isolated value drafts prior to explicit save).

### LP-012: Fast-Path Rulebook for Micro-Interactivity
* **Rule**: Real-time drag/snap feedback must run deterministically on-device in `< 100ms` (`FastPathRulebook`). Async LLM calls are reserved for open chat and stage evaluation.

### LP-015: Wall Thickness Drywall Bounding Box Trap
* **Rule**: RoomPlan/procedural perimeter wall meshes have physical thickness; clamp interior placements using interior clearance bounds (`width/2 - wallHalfThickness`) so objects do not clip into walls.

### LP-016: Cutaway Wall Shadow Pass Trap
* **Problem**: Toggling `wall.isEnabled = !isHidden` during camera orbit removes the wall entity from RealityKit's shadow map depth pass, causing shadows to abruptly pop in and out.
* **Rule**: On iOS 18+, keep `wall.isEnabled = true` and apply `OpacityComponent(opacity: 0.0)` when hidden, removing the component when visible. Anchor sunlight with `shadowProjection: .fixed(...)` relative to room space.

### LP-017: Synced Project & Signing Discipline
* **Rule**: `Alcove.xcodeproj/project.xcproj` uses Xcode synchronized folder groups, so new Swift files and `.colorset` assets under `Alcove/` and `AlcoveTests/` are picked up automatically. Keep local signing overrides (`DEVELOPMENT_TEAM`, `PRODUCT_BUNDLE_IDENTIFIER`) out of PRs and commits.
