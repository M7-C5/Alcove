# ADR-0003: Modern Value-Based VSA Router & Spatial Simulation Contracts

* Status: accepted
* Deciders: Engineering & Architecture
* Date: 2026-11-09

## Context and Problem Statement

Following the vertical slice partitioning in ADR-0002, cross-slice transitions were still tightly coupled:
1. `DashboardView` directly constructed `StageListView(room: room)`.
2. `StageListView` directly constructed `Studio3DView(room: room, stage: stage)`.
3. Navigation state was tied to implicit SwiftUI hierarchy instead of programmatic control, preventing deep linking, state-driven pops, and automated integration tests.
4. Stage 3 (The Illumination) lacked layered lighting simulation contracts (Daylight, Ambient, Task, Accent) and fixture data contracts.
5. Stage 4 (The Harmony Reveal) lacked structured Before/After comparison models and metrics synthesis.
6. Mascot feedback lacked unified haptic and audio/speech feedback contracts.
7. 3D spatial viewport lacked structured camera presets (dollhouse 3D isometric vs 2D plan) and gestures.

## Decision Drivers

* Complete slice decoupling: slices must not reference other feature slices' views directly.
* Programmatic navigation with value-based routing (`NavigationLink(value:)` and `NavigationRouter`).
* Live `@Model` reference passing via type-safe, Hashable routes (`AlcoveRoute`).
* Multi-layer lighting simulation adhering to architectural interior standards.
* Objective before/after spatial comparison metrics for curriculum assessment.
* Non-blocking audio/TTS/haptics contracts with complete headless testability.
* Multi-angle camera viewport presets with pinch/pan gestures.

## Decision Outcome

Chosen design:
1. **Modern Value-Based Navigation Router (`Alcove/Navigation/`)**:
   - `AlcoveRoute: Hashable`: strongly-typed route enum carrying live `@Model` references (`.stageList(Room)`, `.studio(room: Room, stage: StageType)`).
   - `NavigationRouter: Observable`: manages `NavigationPath`, providing programmatic `push(_:)`, `pop()`, and `popToRoot()`.
   - Navigation container registers `.navigationDestination(for: AlcoveRoute.self)` and injects `NavigationRouter` via SwiftUI environment.
   - Slices emit `NavigationLink(value:)` without knowing the destination view type.
   - Located in dedicated top-level `Alcove/Navigation/` and tested in `AlcoveTests/Navigation/NavigationRouterTests.swift`.
2. **Illumination Simulation Contracts (Stage 3) (`Alcove/Features/Studio3D/Stages/Stage3_Illumination/`)**:
   - Defined `LightLayer` (`.daylight`, `.ambient`, `.task`, `.accent`), `LightFixture`, and `IlluminationSimulationEngine` for lux/lumens calculations and Blackbody color temperatures.
   - Colocated within the Studio3D Stage 3 vertical slice and tested in `AlcoveTests/Features/Studio3D/Stages/Stage3_IlluminationTests.swift`.
3. **Harmony Before/After Comparison Model (Stage 4) (`Alcove/Features/Studio3D/Stages/Stage4_Harmony/`)**:
   - Defined `HarmonyComparisonModel` and `HarmonySynthesisEngine` evaluating circulation deltas, usable floor area, and visual split reveals.
   - Colocated within the Studio3D Stage 4 vertical slice and tested in `AlcoveTests/Features/Studio3D/Stages/Stage4_HarmonySynthesisEngineTests.swift`.
4. **Spatial Viewport Camera & Gestures (`Alcove/Features/Studio3D/Viewport/`)**:
   - Defined `ViewportPreset` (Top-down, Isometric Dollhouse, Front Elevation, Side) and `SpatialViewportCameraState` supporting pinch zoom and pan.
   - Colocated within the Studio3D Viewport vertical slice and tested in `AlcoveTests/Features/Studio3D/Viewport/SpatialViewportCameraTests.swift`.
5. **Mascot Feedback & Haptics Contracts (`Alcove/Core/Services/`)**:
   - Defined `MascotFeedbackServiceProtocol` with `SystemMascotFeedbackService` (tactile haptics & `AVSpeechSynthesizer` narration) and `MockMascotFeedbackService` for unit testing.
   - Retained in `Alcove/Core/Services/` as universal companion contracts, tested in `AlcoveTests/Core/MascotFeedbackServiceTests.swift`.
6. **SwiftData Persistence & Preview Mocking (`Alcove/Core/Storage/`)**:
   - Provided `ModelContainer.createPreviewContainer()` and `ModelContainer.createInMemoryContainer()` for testing and SwiftUI previews.
   - Retained in `Alcove/Core/Storage/`, tested in `AlcoveTests/Core/ModelContainerPreviewTests.swift`.

### Architectural Layout ("Skinny Core, Fat Slices")

* **`Alcove/Core/`**: Contains ONLY pure persistent schema models (`Core/Models/`), cross-feature Mascot AI / Feedback companion contracts and fast-path rulebooks (`Core/Services/`), and preview storage helpers (`Core/Storage/`).
* **`Alcove/Navigation/`**: Houses value-based routing logic decoupled from presentation slices.
* **`Alcove/Features/`**: Houses rich feature domains with their own stages, calculation engines, view models, and views.
* **`AlcoveTests/`**: Mirrors the exact hierarchy, isolating unit test runs per vertical slice.
