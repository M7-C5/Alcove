# Alcove 🛋️

> Gamified, educational interior design for iPad. Redesign your own living spaces stage-by-stage with an interactive AI Mascot Companion.

---

## Overview

**Alcove** transforms interior design learning into an interactive 3D spatial simulation. Instead of passive tutorials, users scan or import their real rooms and progress through a structured 4-stage design curriculum:

1. **The Audit**: Spatial bottleneck inspection, clearance analysis, and mascot onboarding.
2. **The Rearrangement**: Interactive furniture repositioning, circular rotation snapping, inventory archive, and catalog add/swap/remove.
3. **The Illumination**: Three-column lighting workspace with room compass daylight simulation and multi-fixture placement.
4. **The Harmony Reveal**: Before/After split comparison, comprehensive design scorecard, and 1:1 AR walkthrough.

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
│   ├── Models/       # SwiftData models (Room, Layout, Furniture, StageProgress)
│   ├── Services/     # Mascot AI, Fast-path rulebook, Evaluation & spatial engines
│   └── Storage/      # Seed data, sample rooms, and FurnitureCatalog presets
├── Features/
│   ├── Home/         # Landing view and entry navigation
│   ├── Dashboard/    # Room gallery, RoomPlan scan, and compass capture
│   ├── Stages/       # 4-stage progression cards
│   ├── Studio3D/     # RealityKit viewport, Sims HUD, Stage 3 & 4 workspaces
│   ├── ARWalkthrough/# 1:1 scale AR room walkthrough
│   └── MascotChat/   # Advisory dialogue and conversational LLM
├── Navigation/       # Value-based VSA navigation router
└── UI/               # Shared Light-only Alcove* color tokens and HUD components
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
