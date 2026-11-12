# AGENTS.md — Alcove Agentic Workflow & Collaboration Guide

Welcome to the **Alcove** codebase. This file specifies instructions, rules, and protocols for AI agents working in this repository.

---

## 1. Project Overview & Philosophy

**Alcove** is an interior design educational app for iPad (native landscape). Users scan or import their own rooms and progress through a 4-stage pedagogical curriculum:
1. **The Audit**: Spatial analysis, bottleneck discovery, clearance checks.
2. **The Rearrangement**: Furniture placement, orientation, circulation flow.
3. **The Illumination**: Daylight path, ambient/task/accent lighting balance.
4. **The Harmony Reveal**: Before/After split comparison, room scorecard, walkthrough.

Users are accompanied on every stage by an interactive **Mascot AI Companion** providing onboarding, real-time feedback, open chat, and stage completion evaluations.

---

## 2. Directory Architecture

```
Alcove/
├── .agents/
│   ├── rules/
│   │   ├── 00-general-engineering.md       # Sendable, nil safety, value decoupling
│   │   ├── 01-verification-loop.md         # Autonomous test verification & thermal guard
│   │   ├── 02-swift-apple-architecture.md   # SwiftData models, Vertical Slices, HIG
│   │   ├── 03-apple-hig-design-standards.md # iPad landscape HUD, 44pt touch targets
│   │   └── 04-learned-patterns.md          # LP-001 through LP-015 patterns & traps
│   └── skills/
│       ├── code-review/SKILL.md            # Adversarial Swift 6, @MainActor, and HIG checklist
│       ├── perf-audit/SKILL.md             # Compile flags, RealityKit retain cycles, fast-path latency
│       ├── scaffold-module/SKILL.md        # Contract-first vertical slice scaffolding
│       ├── security-audit/SKILL.md         # SwiftData local security, ATS, and entitlements
│       └── ui-audit/SKILL.md               # iPad landscape ergonomics, 44pt targets, contrast
├── .github/
│   └── pull_request_template.md            # Standardized PR template
├── docs/
│   ├── AGENTIC_PLAYBOOK.md                 # Agentic collaboration axioms, curriculum & circuit breakers
│   ├── ARCHITECTURE.md                     # Deep technical and domain architecture
│   ├── RECIPES.md                          # Prompt recipes for scaffolding, triage & zero-miss delivery
│   └── adr/                                # Architectural Decision Records (MADR format)
├── scripts/
│   ├── audit-ui.sh                         # Headless multimodal iPad visual contrast & Dynamic Type inspector
│   ├── changelog.sh                        # Automated conventional commit changelog generator
│   ├── install-hooks.sh                    # Conventional commit & raw path git hook installer
│   └── verify.sh                           # Fast verification and test runner with thermal cleanup
├── Alcove/
│   ├── MyApp.swift                         # App entrypoint & SwiftData schema configuration
│   ├── Core/
│   │   ├── Models/                         # SwiftData models (Room, Layout, Furniture, StageProgress)
│   │   ├── Services/                       # Mascot AI, evaluation engine, fast-path rules
│   │   └── Storage/                        # Seed data, sample rooms, sample furniture assets
│   ├── Features/
│   │   ├── Dashboard/                      # Room list & scan launcher
│   │   ├── Stages/                         # 4-stage progression cards & stage launcher
│   │   ├── Studio3D/                       # RealityKit 3D viewport, mascot HUD, dialogue overlay
│   │   └── MascotChat/                     # Mascot conversation sheet & evaluation dialog
│   └── UI/                                 # Reusable HUD elements, cards, buttons, dials
└── AlcoveTests/                            # Swift Testing / XCTest suite
```

---

## 3. Engineering Operating Standards

### Git Branch & Commit Protocol
- Atomic commits adhering to Conventional Commits: `<type>(<scope>): <subject>`.
- Local branch flow: `dev` (feature development) $\rightarrow$ `staging` (pre-release validation) $\rightarrow$ `main` (production).

### Verification & Thermal Management
- Run verification locally using:
  ```bash
  ./scripts/verify.sh
  ```
- **Execution Scoping**:
  - **Required**: Run `./scripts/verify.sh` strictly after authoring or modifying Swift source code (`Alcove/`, `AlcoveTests/`, project config) prior to declaring task completion.
  - **Prohibited**: Do NOT run `./scripts/verify.sh` on markdown/docs updates, clean `git pull` operations, planning, or general queries.
- Always shut down simulators after test runs to preserve battery and thermal headroom:
  ```bash
  xcrun simctl shutdown all 2>/dev/null || true
  ```

---

## 4. Conventional Commit Standards

| Type | Description |
|---|---|
| `feat` | A new user-facing feature |
| `fix` | A bug fix |
| `refactor` | Code restructuring without functional change |
| `test` | Adding or updating tests |
| `docs` | Documentation changes |
| `chore` | Build scripts, tooling, or project configuration |
| `perf` | Code changes that improve performance |
| `ci` | CI/CD pipeline modifications |

---

## 5. Domain Rules & Specialized Skills

When working in specific functional areas, consult and follow the corresponding rulebooks and superpower skills:
- **Scaffold Module** (`.agents/skills/scaffold-module/SKILL.md`): Contract-first vertical slice development.
- **Code Review** (`.agents/skills/code-review/SKILL.md`): Adversarial checklist for `@MainActor`, Swift 6 `Sendable`, and iPad landscape HUD touch targets.
- **Performance Audit** (`.agents/skills/perf-audit/SKILL.md`): Compile overhead, RealityKit entity retain cycles, and fast-path reaction latency.
- **Security Audit** (`.agents/skills/security-audit/SKILL.md`): Local SwiftData file protection, on-device boundaries, and ATS.
- **UI & HIG Audit** (`.agents/skills/ui-audit/SKILL.md`): iPad landscape ergonomics, 44pt touch targets, Dynamic Type, and contrast symmetry.

