# Alcove 🛋️

> Gamified, educational interior design for iPad. Redesign your own living spaces stage-by-stage with an interactive AI Mascot Companion.

---

## Overview

**Alcove** transforms interior design learning into an interactive 3D spatial simulation. Instead of passive tutorials, users scan or import their real rooms and progress through a structured 4-stage design curriculum:

1. **The Audit**: Spatial bottleneck inspection, clearance analysis, and mascot onboarding.
2. **The Rearrangement**: Interactive furniture repositioning with circular rotation snapping and inventory storage.
3. **The Illumination**: Daylight path scrubbing and balanced ambient/task/accent lighting.
4. **The Harmony Reveal**: Before/After split comparison, comprehensive design scorecard, and AR walkthrough.

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
