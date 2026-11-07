# Alcove Architecture Specification

This document details the software architecture, domain model, user interaction patterns, and data flow of **Alcove**.

---

## 1. Vision & Core Principles

Alcove empowers users to master interior design fundamentals by redesigning their **own real-world spaces** in iPad native landscape.

Key Principles:
1. **Curriculum-Driven Spatial Learning**: Every stage teaches concrete design principles (flow, circulation, daylighting, balance).
2. **Companion Guidance**: A persistent 3D/2D Mascot acts as teacher, critic, and cheerleader.
3. **Player Autonomy**: Advisory evaluation gates provide clear critiques while allowing a `"Proceed Anyway"` override.
4. **Safety & Comparison**: Dual layout preservation ensures users can always revert to their original room scan and compare Before/After.

---

## 2. System Architecture

```mermaid
flowchart TD
    App[Alcove App] --> DB[SwiftData ModelContainer]
    App --> Nav[Navigation Coordinator]

    Nav --> Dashboard[DashboardView]
    Dashboard --> Scanner[RoomPlan Scanner]
    Dashboard --> StageList[StageListView]

    StageList --> Studio[Studio3DView]
    
    subgraph Studio3D[Studio 3D Viewport]
        Viewport[RealityKit Viewport]
        MascotHUD[Mascot Action Bar]
        DialogueBox[Visual Novel Dialogue Overlay]
        Controls[Stage-Gated Tools]
    end

    Studio --> MascotService[Mascot AI Service]
    MascotService --> FastPath[FastPath Rulebook <100ms]
    MascotService --> LLM[LLM Chat & Evaluation Engine]

    Studio --> LayoutEngine[Dual Layout Engine]
    LayoutEngine --> Baseline[Baseline Layout (Immutable)]
    LayoutEngine --> Working[Working Layout (Mutable)]
```

---

## 3. Four-Stage Educational Curriculum

### Stage 1: The Audit (Spatial Analysis)
- **Goal**: Understand circulation flow, entry points, natural light orientation, and bottleneck zones.
- **Controls**: View-only navigation (orbit, pan, zoom).
- **Mascot Interaction**: Welcomes user to room, highlights tight clearances (< 60cm walkway) or blocked windows, provides audit summary.
- **Proceed Gate**: User must review bottlenecks or tap "Proceed Anyway".

### Stage 2: The Rearrangement (Layout & Flow)
- **Goal**: Optimize furniture arrangement, focal points, and clear walkways.
- **Controls**: Floor drag gestures, circular rotation dial ($45^\circ$ snap), inventory sheet (storing unneeded items).
- **Mascot Interaction**: Micro-reactions on furniture moves (e.g., "Great focal point towards the window!").
- **Proceed Gate**: Evaluates walkway clearances, focal alignment, and room balance.

### Stage 3: The Illumination (Daylight & Fixtures)
- **Goal**: Balance natural daylight and artificial lighting layers (ambient, task, accent).
- **Controls**: Sun-scrubber dial (simulates 8 AM to 8 PM daylight angle) + artificial light placement.
- **Mascot Interaction**: Comments on shadow density and lighting warmness.
- **Proceed Gate**: Evaluates dark spots and task lighting near desk/bed/sofa.

### Stage 4: The Harmony Reveal (Synthesis & Validation)
- **Goal**: Celebrate transformation and validate real-world feasibility.
- **Controls**: Interactive Before/After split slider, comprehensive Room Scorecard, AR floor preview.
- **Mascot Interaction**: Final graduation speech, awarding room mastery badge.

---

## 4. Domain Data Model (SwiftData)

### `Room`
- `id: UUID`: Unique identifier.
- `name: String`: Room title (e.g. "Primary Bedroom").
- `createdAt: Date`: Capture timestamp.
- `dimensionsWidth: Double`: Room width in meters.
- `dimensionsLength: Double`: Room length in meters.
- `dimensionsHeight: Double`: Room ceiling height in meters.
- `baselineLayout: Layout`: Immutable scanned layout.
- `workingLayout: Layout`: Active working layout.
- `stageProgress: [StageProgress]`: Progression record for each stage.

### `Layout`
- `id: UUID`: Unique identifier.
- `furnitures: [Furniture]`: Furniture items in the layout.
- `isBaseline: Bool`: Flag distinguishing original scan from working draft.

### `Furniture`
- `id: UUID`: Unique identifier.
- `name: String`: Descriptive name.
- `category: FurnitureCategory`: Seating, storage, surface, bed, lighting, decor.
- `positionX: Double`, `positionY: Double`, `positionZ: Double`: Position in RealityKit coordinates.
- `rotationYaw: Double`: Rotation in radians around vertical Y axis.
- `width: Double`, `length: Double`, `height: Double`: Bounding box dimensions in meters.
- `isArchived: Bool`: True if placed in inventory.

### `StageProgress`
- `stage: StageType`: `.audit`, `.rearrangement`, `.illumination`, `.harmony`.
- `isCompleted: Bool`: Completed status.
- `isUnlocked: Bool`: Access status.
- `score: Int`: Evaluated score (0-100).
- `feedback: String`: Mascot feedback summary.

---

## 5. Mascot AI & Fast-Path Architecture

To maintain high responsiveness on iPad:
1. **Fast-Path Rulebook (`< 100ms`)**:
   - Pure local heuristic evaluation on furniture drag and drop.
   - Triggers quick floating emoji/speech bubble reactions (e.g., clearance warning, focal point praise).
2. **Advisory Stage Evaluation**:
   - Deep structural evaluation combining heuristic spatial metrics with contextual LLM guidance.
   - Evaluates:
     - Clearance flow ($\ge 60\text{ cm}$ walkways).
     - Focal alignment (furniture oriented towards focal point).
     - Lighting coverage (no severe dark corners).
   - Generates score, highlights bottlenecks, and provides actionable advice.
   - **Advisory Override**: If the user desires to advance regardless of score, `"Proceed Anyway"` is permanently accessible.
3. **Conversational Assistant**:
   - Bottom-left chat button opens a contextual dialogue drawer.
   - Mascot answers questions about interior design principles with current room context.
