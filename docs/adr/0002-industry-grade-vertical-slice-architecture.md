# ADR-0002: Industry-Grade Vertical Slice Architecture (VSA)

* Status: accepted
* Deciders: Engineering & Architecture
* Date: 2026-11-09

## Context and Problem Statement

As Alcove matured from a prototype to a full curriculum-driven interior design application, feature files grew into monolithic structs mixing state management, canvas coordinate calculations, persistence queries, and service orchestration into single SwiftUI view definitions (e.g. `Studio3DView.swift` exceeding 570 lines).

We needed an industry-grade Vertical Slice Architecture (VSA) ensuring:
1. High cohesion within slices (each slice completely owns its UI, `@Observable @MainActor` ViewModel, subcomponents, and presentation logic).
2. Minimal coupling between slices (slices depend strictly on pure domain `Core` contracts, models, and services).
3. First-class testability where view models and domain invariants are unit tested headlessly without UI host dependencies.
4. Test suite partitioning mirroring the vertical slice boundaries.

## Decision Drivers

* Maintainability & readability: views must adhere to declarative SwiftUI standards and stay concise (< 80 lines for main bodies).
* Architectural isolation: changing one slice (e.g. Dashboard room filtering or Studio3D tool rotation) must not cause regressions in another.
* Modern Swift 6 & `@Observable` standard: eliminating legacy `@StateObject` / `@Published` in favor of Swift Observation.
* Deterministic unit test partitioning across `AlcoveTests`.

## Considered Options

1. **Layered / N-Tier Architecture**: Horizontal layers (`Models/`, `ViewModels/`, `Views/`, `Services/`).
2. **Standard Modular SPM Packages**: Partitioning each slice into a standalone Swift Package.
3. **In-Target Vertical Slice Architecture (VSA)**: Organizing within `Alcove/Features/<SliceName>/` with dedicated ViewModels, subcomponent trees, and corresponding `AlcoveTests/Features/<SliceName>/` test suites.

## Decision Outcome

Chosen option: **Option 3: In-Target Vertical Slice Architecture (VSA)**, because:
* VSA provides maximum feature cohesion: all code required to understand, debug, or extend a slice resides in a unified directory.
* Avoids SPM cross-package compile graph overhead while preparing the codebase for clean SPM extraction once target compilation times warrant it.
* Decouples the presentation state into `@Observable @MainActor` view models, enabling isolated unit test coverage for complex user flows (stage gating, spatial moves, tool locking, chat dispatch).

### Structure Implemented: "Skinny Core, Fat Slices"

To prevent architectural degradation and cross-cutting domain bloat in `Core`, Alcove enforces a strict **"Skinny Core, Fat Slices"** vertical slice pattern:
* **Core**: Restricted strictly to pure SwiftData persistence entities (`Models/`), application-wide Mascot AI and feedback companion contracts (`Services/`), and model container preview seeding (`Storage/`).
* **Navigation**: Top-level cross-slice coordination via value-based routing (`Navigation/`).
* **Features**: Feature domain engines, algorithms, stage calculation engines, viewports, view models, and subviews reside entirely within their respective vertical slices (`Features/`).

```
Alcove/
├── Core/             # Skinny Core: persistent schemas, companion contracts, preview storage
│   ├── Models/       # SwiftData @Model entities (Room, Layout, Furniture, StageProgress, StageType)
│   ├── Services/     # Shared companion contracts & rulebooks (MascotAIService, MascotFeedbackService, FastPathRulebook)
│   └── Storage/      # Previews & sample test data (ModelContainer+Preview, SampleData)
├── Navigation/       # Value-based cross-slice router & routes (AlcoveRoute, NavigationRouter)
└── Features/         # Fat Slices: feature domain engines, viewmodels, subcomponents & stages
    ├── Dashboard/
    │   ├── DashboardView.swift
    │   ├── DashboardViewModel.swift
    │   └── Components/ (RoomCardView.swift, RoomScanSheet.swift)
    ├── Stages/
    │   ├── StageListView.swift
    │   ├── StageListViewModel.swift
    │   └── Components/ (StageCardView.swift)
    ├── Studio3D/
    │   ├── Studio3DView.swift
    │   ├── Studio3DViewModel.swift
    │   ├── Viewport/ (ViewportPreset.swift, SpatialViewportCameraState.swift)
    │   ├── Stages/
    │   │   ├── Stage3_Illumination/ (LightFixture.swift, IlluminationSimulationEngine.swift)
    │   │   └── Stage4_Harmony/ (HarmonySynthesisEngine.swift, HarmonyComparisonModel.swift)
    │   └── Components/ (RoomSpatialCanvas.swift, FloorGridView.swift, StudioTopHUD.swift, StudioBottomHUD.swift, StudioToolbars.swift)
    └── MascotChat/
        ├── MascotChatDrawer.swift
        ├── MascotChatViewModel.swift
        └── StageEvaluationSheet.swift

AlcoveTests/
├── Core/             # Pure Core tests: persistent schema, storage previews, mascot service
│   ├── AlcoveCoreTests.swift
│   ├── ModelContainerPreviewTests.swift
│   └── MascotFeedbackServiceTests.swift
├── Navigation/       # NavigationRouterTests
└── Features/
    ├── Dashboard/    # DashboardViewModelTests
    ├── Stages/       # StageListViewModelTests
    ├── Studio3D/
    │   ├── Studio3DViewModelTests.swift
    │   ├── Viewport/ (SpatialViewportCameraTests.swift)
    │   └── Stages/ (Stage3_IlluminationTests.swift, Stage4_HarmonySynthesisEngineTests.swift)
    └── MascotChat/   # MascotChatViewModelTests
```

### Positive Consequences

* Slices are fully self-contained and testable in sub-second headless execution.
* Monolithic 570-line view broken into focused, single-responsibility components with clear separation between state, math, and rendering.
* Swift Testing suites increased from 6 to 52 automated unit tests across 12 suites executing in sub-second time.
* Follows Apple Human Interface Guidelines and Swift 6 `@Observable` / `@MainActor` standards.

### Negative Consequences

* Introduces more individual files per feature slice.
