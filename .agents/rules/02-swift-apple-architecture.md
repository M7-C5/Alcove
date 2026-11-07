# Swift & Apple Architecture Standards

1. **Vertical Feature-Slice Modularization**:
   - Organize code into clean vertical slices:
     - `Core/Models`: Domain models (`Room`, `StageProgress`, `Furniture`).
     - `Core/Services`: Service protocols (`MascotAIServiceProtocol`) and implementations.
     - `Features/Dashboard`: Room collection grid and scan entry points.
     - `Features/RoomScan`: RoomPlan LiDAR capture pipeline.
     - `Features/StageList`: 4-stage progression cards.
     - `Features/Studio3D`: RealityKit 3D viewport, Sims-style manipulation, and Mascot HUD.

2. **SwiftData Invariants**:
   - Use SwiftData `@Model` for persistence.
   - Maintain a clear separation between immutable baseline scan snapshots (`baselineLayout`) and mutable active editing drafts (`workingLayout`).

3. **Modern Swift Testing**:
   - Use Swift Testing (`import Testing`) with `@Suite`, `@Test`, and `#expect(...)` macros for unit tests.
