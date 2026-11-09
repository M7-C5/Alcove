# Dynamic Learning Memory & Living Post-Mortem Ledger

> **Purpose**: This living rule file captures empirical developer corrections, spatial traps, Xcode/Swift quirks, and project post-mortems.
> **Loading Invariant**: In accordance with the **Progressive Disclosure Principle**, Antigravity and subagents consult this ledger before proposing code changes.

---

## 📋 Learned Patterns Index

| ID | Category | Title | Heuristic Summary | Date Added |
| :--- | :--- | :--- | :--- | :--- |
| **LP-001** | Portability | Machine-Specific Path Prohibition | Never use absolute machine paths (`/Users/...`); always use clean repository-relative project paths. | 2026-11-08 |
| **LP-002** | Git Discipline | Conventional Commits Specification | Atomic commits following `<type>(<scope>): <subject>`. No commits without explicit user approval. | 2026-11-08 |
| **LP-003** | Architecture | Subagent & Verification Delegation | Read-only subagents must have strictly bounded scopes and never mutate files or execute git commands. | 2026-11-08 |
| **LP-004** | Architecture | Clean-Slate Architecture | Never copy-paste legacy code from prior projects; build purposeful, idiomatic Swift domain types. | 2026-11-08 |
| **LP-005** | Verification | Thermal Guard & Simulator Lifecycle | Background simulators exhaust CPU and thermals; scripts must cleanly shut down simulators on exit. | 2026-11-08 |
| **LP-006** | SwiftUI HIG | iPad Native Landscape HUD Layout | Lock to landscape; anchor Mascot HUD bottom-left with adjacent dialogue to keep 3D view interactive. | 2026-11-08 |
| **LP-007** | SwiftUI | Model Propagation & State Traps | Avoid dynamic `@Query` inside navigation destinations; pass direct `@Bindable` model references. | 2026-11-08 |
| **LP-008** | SwiftUI | Layout Expansion (`.position()` Trap) | `.position(x:y:)` greedily fills parent frame; use `.offset()` or `ZStack` alignment anchors instead. | 2026-11-08 |
| **LP-009** | RealityKit | 3D Coordinate Alignment | Right-handed coordinates ($+X$ right, $+Y$ up, $+Z$ towards viewer); floor at $Y=0$, clamp within bounds. | 2026-11-08 |
| **LP-010** | Game Design | Advisory Evaluation Gate with Override | Never permanently trap users on subjective gates; always provide a `"Proceed Anyway"` override. | 2026-11-08 |
| **LP-011** | SwiftData | Dual Layout Immutability | Preserve scanned room state in immutable `baselineLayout`; apply all user edits to `workingLayout`. | 2026-11-08 |
| **LP-012** | Performance | Fast-Path Rulebook for Micro-Interactivity | Real-time drag reactions must execute in `<100ms` via local heuristics; reserve LLMs for chat & stage gates. | 2026-11-08 |
| **LP-013** | Concurrency | Swift 6 Concurrency & Actor Isolation | UI ViewModels and services must be `@MainActor`; domain transfer objects must conform to `Sendable`. | 2026-11-08 |
| **LP-014** | Spatial USD | USD Catmull-Clark Subdivision Trap | OpenUSD defaults to `catmullClark`, turning cuboid meshes into marshmallows. Set `subdivisionScheme = "none"`. | 2026-11-09 |
| **LP-015** | Spatial RoomPlan | Wall Thickness Drywall Bounding Box Trap | Outer bounds include wall prism thickness (~0.5m). Offset by wall half-thickness to prevent wall clipping. | 2026-11-09 |

---

## 🔍 Detailed Heuristic Profiles

### LP-001: Machine-Specific Path Prohibition
* **Context**: Absolute machine paths leak individual user environment details and break portability across CI runners and developer workstations.
* **Bad Pattern**:
  ```markdown
  <!-- ❌ Leaks local machine path and breaks on other machines -->
  See architecture documentation at [Architecture](file:///local/machine/path/to/docs/ARCHITECTURE.md).
  ```
* **Good Pattern**:
  ```markdown
  <!-- ✅ Clean, portable repository-relative path -->
  See architecture documentation at [Architecture](docs/ARCHITECTURE.md).
  ```

---

### LP-002: Conventional Commits Specification
* **Context**: Commit histories must remain clean, searchable, and machine-parsable for automated changelogs. Commits must be atomic and authorized.
* **Bad Pattern**:
  ```bash
  # ❌ Monolithic commit with vague non-standard message
  git commit -m "fixed bugs in 3d view and updated docs"
  ```
* **Good Pattern**:
  ```bash
  # ✅ Atomic conventional commit with clear domain scope
  git commit -m "fix(studio): clamp furniture translation to interior room boundaries"
  ```

---

### LP-003: Subagent & Verification Delegation
* **Context**: Bounded delegation prevents runaway subagents from modifying repository state or performing unintended mutating operations.
* **Bad Pattern**:
  ```markdown
  <!-- ❌ Unbounded subagent prompt allowing arbitrary modifications and commits -->
  "Refactor the app architecture and commit your changes."
  ```
* **Good Pattern**:
  ```markdown
  <!-- ✅ Scoped, read-only subagent prompt with explicit boundary invariants -->
  "Conduct an adversarial code review on the working diff. Do NOT edit any files or run git commands. Report findings only."
  ```

---

### LP-004: Clean-Slate Architecture
* **Context**: Copying legacy architectures across codebases introduces stale patterns and dead weight. Alcove requires purposeful, modern Swift.
* **Bad Pattern**:
  ```swift
  // ❌ Importing legacy baggage or copy-pasting obsolete controllers
  import LegacyResignFramework
  class StudioController: LegacyResignBaseViewController { ... }
  ```
* **Good Pattern**:
  ```swift
  // ✅ Purpose-built, lightweight SwiftData domain model
  @Model
  public final class Room {
      public var id: UUID
      public var name: String
      public var dimensionsWidth: Double
      public var dimensionsLength: Double
      public var dimensionsHeight: Double
      public var baselineLayout: Layout?
      public var workingLayout: Layout?
      public var stageProgress: [StageProgress]
  }
  ```

---

### LP-005: Thermal Guard & Simulator Lifecycle
* **Context**: Background simulator instances consume substantial CPU and thermal resources, causing throttling on developer devices.
* **Bad Pattern**:
  ```bash
  # ❌ Runs tests and leaves simulator clones running indefinitely
  xcodebuild test -scheme Alcove -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4)"
  # Process exits, leaving simulator consuming battery
  ```
* **Good Pattern**:
  ```bash
  # ✅ Guaranteed trap to terminate simulators on script exit
  cleanup() {
    xcrun simctl shutdown all 2>/dev/null || true
  }
  trap cleanup EXIT
  ```

---

### LP-006: iPad Native Landscape HUD Layout
* **Context**: Alcove is designed landscape-first. Full-screen modal sheets or portrait assumptions obstruct the 3D spatial viewport.
* **Bad Pattern**:
  ```swift
  // ❌ Vertical sheet covers 60% of screen, occluding 3D room
  VStack {
      RealityKitViewport()
      MascotSheet()
  }
  ```
* **Good Pattern**:
  ```swift
  // ✅ Docked bottom-left HUD preserving unobstructed 3D interaction
  ZStack(alignment: .bottomLeading) {
      RealityKitViewport()
          .ignoresSafeArea()
      
      HStack(alignment: .bottom, spacing: 16) {
          MascotHUDView()
          DialogueOverlayView()
      }
      .padding(.leading, 24)
      .padding(.bottom, 24)
  }
  ```

---

### LP-007: SwiftUI Model Propagation & State Traps
* **Context**: Initializing `@Query` dynamically inside pushed navigation destinations causes blank screens or stale data in iOS 17/18.
* **Bad Pattern**:
  ```swift
  // ❌ Fragile: dynamic @Query inside navigation destination struct init
  struct StageDestinationView: View {
      @Query private var rooms: [Room]
      init(roomId: UUID) {
          _rooms = Query(filter: #Predicate<Room> { $0.id == roomId })
      }
  }
  ```
* **Good Pattern**:
  ```swift
  // ✅ Robust: pass explicit @Bindable model reference directly
  struct StageDestinationView: View {
      @Bindable var room: Room
      
      var body: some View {
          Studio3DView(room: room)
      }
  }
  ```

---

### LP-008: SwiftUI Layout Expansion (`.position()` Trap)
* **Context**: Applying `.position(x:y:)` to a SwiftUI view causes the view to expand and greedily fill the entire parent container frame.
* **Bad Pattern**:
  ```swift
  // ❌ View inflates to occupy full available container space
  MascotReactionBubble(text: "Tight walkway!")
      .position(x: 120, y: 80)
  ```
* **Good Pattern**:
  ```swift
  // ✅ Preserves natural intrinsic sizing via offset or alignment
  MascotReactionBubble(text: "Tight walkway!")
      .offset(x: 16, y: -40)
  ```

---

### LP-009: RealityKit 3D Coordinate Alignment
* **Context**: RealityKit uses a right-handed coordinate system ($+X$ right, $+Y$ up, $+Z$ towards viewer). Floor sits at $Y=0$.
* **Bad Pattern**:
  ```swift
  // ❌ Arbitrary negative Y coordinate drops furniture below floor plane
  entity.position = SIMD3<Float>(targetX, -0.45, targetZ)
  ```
* **Good Pattern**:
  ```swift
  // ✅ Grounded at Y=0 and clamped strictly within room dimensions
  let halfW = Float(room.dimensionsWidth) / 2 - Float(item.width) / 2
  let halfL = Float(room.dimensionsLength) / 2 - Float(item.length) / 2
  let clampedX = min(max(targetX, -halfW), halfW)
  let clampedZ = min(max(targetZ, -halfL), halfL)
  entity.position = SIMD3<Float>(clampedX, 0, clampedZ)
  ```

---

### LP-010: Advisory Evaluation Gate with Override
* **Context**: Algorithmic layout evaluations should guide, not dictate. Hard-blocking users from advancing creates friction.
* **Bad Pattern**:
  ```swift
  // ❌ User is trapped if heuristic score is below threshold
  Button("Next Stage") { advance() }
      .disabled(evaluationScore < 70)
  ```
* **Good Pattern**:
  ```swift
  // ✅ Clear advice provided while permanently respecting player autonomy
  VStack(spacing: 12) {
      if evaluationScore >= 70 {
          Button("Advance to Next Stage", action: advance)
      } else {
          Button("Review Clearances", action: inspectBottlenecks)
          Button("Proceed Anyway", role: .secondary, action: advance)
              .foregroundStyle(.secondary)
      }
  }
  ```

---

### LP-011: Dual Layout Immutability
* **Context**: Users need confidence to experiment. Overwriting original scan geometry eliminates the ability to revert or compare Before/After.
* **Bad Pattern**:
  ```swift
  // ❌ Overwriting scanned layout destroys baseline reference
  func moveFurniture(_ item: Furniture, to pos: SIMD3<Float>) {
      item.positionX = Double(pos.x)
      item.positionZ = Double(pos.z)
  }
  ```
* **Good Pattern**:
  ```swift
  // ✅ Baseline layout is immutable; edits mutate working draft only, with reset capability
  func resetDraft(in room: Room) {
      room.resetWorkingLayoutToBaseline()
  }

  func moveFurniture(_ item: Furniture, to pos: SIMD3<Float>, in room: Room) {
      guard let workingItem = room.workingLayout?.furnitures.first(where: { $0.id == item.id }) else { return }
      workingItem.positionX = Double(pos.x)
      workingItem.positionZ = Double(pos.z)
  }
  ```

---

### LP-012: Fast-Path Rulebook for Micro-Interactivity
* **Context**: Gesture drag updates require `<100ms` response times. Asynchronous network or LLM calls on gesture events create visible latency.
* **Bad Pattern**:
  ```swift
  // ❌ Asynchronous LLM invoked on continuous gesture stream
  .gesture(DragGesture().onChanged { _ in
      Task {
          let advice = await mascotService.evaluateCurrentDrag(room)
          bubbleText = advice
      }
  })
  ```
* **Good Pattern**:
  ```swift
  // ✅ Deterministic local heuristic evaluation for drag reactions
  .gesture(DragGesture().onChanged { gesture in
      let event = FurnitureMoveEvent(
          furnitureName: activeItem.name,
          category: activeItem.category,
          oldPosition: oldPos,
          newPosition: newPos
      )
      if let reaction = FastPathRulebook().evaluateMicroMove(
          event: event,
          roomDimensions: (room.dimensionsWidth, room.dimensionsLength),
          allFurnitures: room.workingLayout?.furnitures ?? []
      ) {
          mascotHUD.displayMicroReaction(reaction.message, emotion: reaction.emotion)
      }
  })
  ```

---

### LP-013: Swift 6 Concurrency & Actor Isolation
* **Context**: Data races occur when UI view models and asynchronous background tasks mutate state concurrently without actor isolation.
* **Bad Pattern**:
  ```swift
  // ❌ Unisolated class susceptible to cross-actor data races
  class StudioViewModel {
      var isEvaluating: Bool = false
      func runAnalysis() async { ... }
  }
  ```
* **Good Pattern**:
  ```swift
  // ✅ Isolated to MainActor with Sendable data structures
  @Observable
  @MainActor
  final class StudioViewModel {
      var isEvaluating: Bool = false
      func runAnalysis() async { ... }
  }
  ```

---

### LP-014: USD Catmull-Clark Subdivision Trap
* **Context**: When generating 3D procedural or box geometry in OpenUSD (`.usda` / `.usdz`), the USD standard specification defaults to `catmullClark` subdivision. RealityKit and QuickLook recursively smooth 6-sided cubes and furniture into rounded marshmallow blobs.
* **Bad Pattern**:
  ```usda
  # ❌ Default subdivision rounds architectural furniture into marshmallows
  def Mesh "CoffeeTable" {
      int[] faceVertexCounts = [4, 4, 4, 4, 4, 4]
      int[] faceVertexIndices = [0, 1, 2, 3, 4, 5, 6, 7, ...]
      point3f[] points = [(-0.5, 0, -0.3), (0.5, 0, -0.3), ...]
  }
  ```
* **Good Pattern**:
  ```usda
  # ✅ Declaring subdivisionScheme = "none" guarantees crisp planar architectural surfaces
  def Mesh "CoffeeTable" {
      uniform token subdivisionScheme = "none"
      int[] faceVertexCounts = [4, 4, 4, 4, 4, 4]
      int[] faceVertexIndices = [0, 1, 2, 3, 4, 5, 6, 7, ...]
      point3f[] points = [(-0.5, 0, -0.3), (0.5, 0, -0.3), ...]
  }
  ```

---

### LP-015: RoomPlan Wall Thickness Drywall Bounding Box Trap
* **Context**: RoomPlan USDZ exports model structural walls as volumetric prisms with ~0.50m thickness. If room boundary clamping uses the outer visual bounds of the root entity (`loaded.visualBounds`), furniture will be allowed to penetrate up to 0.25–0.50m into the wall, sticking through exterior surfaces.
* **Bad Pattern**:
  ```swift
  // ❌ Outer mesh bounds include structural wall thickness (~0.5m), letting furniture clip through walls
  let bounds = roomEntity.visualBounds(relativeTo: nil)
  self.roomHorizontalBounds = (bounds.min.x, bounds.max.x, bounds.min.z, bounds.max.z)
  ```
* **Good Pattern**:
  ```swift
  // ✅ Derive authentic interior drywall faces by offsetting by wall half-thickness (or inner Arch_grp faces)
  let wallHalfThickness: Float = 0.10 // 10-15cm drywall setback
  let interiorMinX = outerBounds.min.x + wallHalfThickness
  let interiorMaxX = outerBounds.max.x - wallHalfThickness
  let interiorMinZ = outerBounds.min.z + wallHalfThickness
  let interiorMaxZ = outerBounds.max.z - wallHalfThickness
  self.roomHorizontalBounds = (interiorMinX, interiorMaxX, interiorMinZ, interiorMaxZ)
  ```
