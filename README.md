# Alcove 🛋️

> Gamified, educational interior design for iPad. Redesign your own living spaces stage-by-stage with an interactive AI Mascot Companion.

---

## Overview

**Alcove** transforms interior design learning into an interactive 3D spatial simulation. Instead of passive tutorials, users scan or import their real rooms and progress through a structured 4-stage design curriculum:

1. **The Audit**: Spatial bottleneck inspection, clearance analysis, and mascot onboarding.
2. **The Rearrangement**: Interactive furniture repositioning with circular rotation snapping and inventory storage.
3. **The Illumination**: Daylight path scrubbing and balanced ambient/task/accent lighting.
4. **The Harmony Reveal**: Before/After split comparison, comprehensive design scorecard, and AR walkthrough.

**The Illumination** uses a three-column workspace: **Your lights** on the left, the RealityKit room in the center, and **Lighting preview** plus **Light settings** on the right. **Add light** locks the main viewport to a top view with a translucent white placement layer. Choose a familiar lamp type, then tap the room to place it on a hidden 5 cm grid. **Done** restores the previous camera preset. Lamp type sets the mounting details automatically; users adjust only light color and brightness. **Save** persists the working layout; the clock and master light switch belong to the studio session. Daylight is illustrative until captured windows and geographic orientation are available.

Use **Test Lighting** on the dashboard to open Illumination immediately with a temporary mock bedroom layout. Add lamps and test the simulation without completing earlier stages. Closing the playground discards its temporary room; reopening starts fresh.

Each light appears as its own 3D lamp model. Desk and table lamps sit on tapped furniture surfaces, standing lamps sit on the floor, and ceiling and wall fixtures mount automatically. Light comes from the lamp head or shade, with a focused beam or diffuse glow appropriate to the type; color and brightness controls update both the model and its illumination.

Tap **Select** in **Your lights** to edit several lamps together. Tap lamps in the list or room, or use **Select all**; checkmarks, a count, and outlines show the selection. Different settings display **Mixed**. Changing lamp type, light color, or brightness applies only that setting to the selected lamps. **Done** returns to editing one lamp; **Save** persists the edits.

---

## Target Platform & Requirements

- **Platform**: iPadOS 18+ (Optimized native landscape)
- **Frameworks**: SwiftUI, RealityKit, SwiftData, RoomPlan
- **Tooling**: Xcode 16+ / Swift 6

---

## Architecture at a Glance

Alcove follows a modular vertical-slice architecture:

```
Alcove/
├── Core/
│   ├── Models/       # Room, Layout, Furniture, StageProgress
│   └── Services/     # Mascot AI service, Fast-path rulebook, Evaluation engine
├── Features/
│   ├── Dashboard/    # Room gallery and room scan launcher
│   ├── Stages/       # 4-stage progression cards
│   ├── Studio3D/     # RealityKit viewport, gesture controls, Mascot HUD
│   └── MascotChat/   # Advisory dialogue and conversational LLM
└── UI/               # Reusable HUD elements, cards, and dials
```

---

## Quick Start

### Build & Verification
To build the project and execute all verifications locally:

```bash
./scripts/verify.sh
```

---

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): Architectural deep-dive and component interactions.
- [AGENTS.md](AGENTS.md): Agent collaboration, commit conventions, and repository rules.
- [docs/adr/](docs/adr/): Architectural Decision Records.

---

## License

Proprietary — All rights reserved.
