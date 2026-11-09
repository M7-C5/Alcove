# Agent Flight Simulator & Prompt Recipes (iPad / Swift)

This document provides battle-tested, turn-by-turn prompt recipes for directing AI agents (such as Antigravity) to build features, audit code, and fix bugs in **Alcove** without hallucination or context bloat.

---

## 🍳 Recipe 1: Contract-First Feature Scaffolding

### Objective
Create a new domain capability (e.g., stage tool, daylight scrubber, furniture asset category, mascot dialogue trigger) with complete interface separation, SwiftData `@Model` or service protocol, in-memory tests, and an iPad landscape SwiftUI view.

### Prompt Template
```markdown
Please scaffold a new feature: [Feature Name] (e.g., Stage 3 Daylight Scrubbing / Wall Collision Gate / Mascot Mood React).

Follow the contract-first protocol:
1. Pure Contract & Model: Define the domain protocol or SwiftData `@Model` in `Alcove/Core/` or `Alcove/Features/`.
2. Swift Testing First: Add unit tests in `AlcoveTests` using in-memory container configurations (`ModelConfiguration(isStoredInMemoryOnly: true)`) to verify creation, mutation, and edge cases.
3. View & ViewModel: Create an `@Observable @MainActor` ViewModel and a declarative SwiftUI View adhering to iPad landscape HIG (44x44pt minimum touch targets, Dynamic Type wrappers, `.continuous` corner radius, semantic colors).
4. Run `./scripts/verify.sh` to confirm compilation and zero test failures before declaring completion.
Do NOT commit to git.
```

---

## 🍳 Recipe 2: Autonomous Bug Fix & Self-Healing Loop

### Objective
Trigger the agent to diagnose and repair a failing test or compiler error autonomously without manual log copy-pasting.

### Prompt Template
```markdown
Run `./scripts/verify.sh` to check for test or build errors.
If errors occur:
1. Inspect the stack trace and locate the failing file and line number.
2. Read the source code around the error without guessing.
3. Implement the root-cause fix (do not weaken test assertions to pass).
4. Re-run `./scripts/verify.sh` until all green.
Only report back when `./scripts/verify.sh` passes cleanly with all simulators shut down.
```

---

## 🍳 Recipe 3: Adversarial Code Review (Skill: `code-review`)

### Objective
Have an adversarial subagent review your staged or proposed changes before presentation or merge.

### Prompt Template
```markdown
Run an adversarial code review on the current git diff using the `code-review` skill.
Specifically scrutinize:
- Concurrency safety: Are UI ViewModels and services marked `@MainActor`? Are types Sendable?
- Memory retention: Are closures capturing `self` with `[weak self]`?
- SwiftData boundaries: Is `ModelContext` isolated properly between UI and background tasks?
- Fast-Path latency: Are gesture-triggered interactions kept local and deterministic (<100ms) without blocking LLM calls?
- Apple HIG: Are semantic system text styles and continuous corner radius tokens used?
Provide a prioritized list of critical risks and recommendations.
```

---

## 🍳 Recipe 4: Apple HIG & Visual Accessibility Polish (Skill: `ui-audit`)

### Objective
Audit and polish SwiftUI views for iPad landscape ergonomics, touch targets, Dynamic Type scaling, and appearance symmetry.

### Prompt Template
```markdown
Use the `ui-audit` skill on `[Path to SwiftUI View]`.
Verify:
1. Touch target geometry: Minimum 44x44pt on all interactive elements (48x48pt for primary HUD buttons).
2. Dynamic Type: Semantic font styles (`.headline`, `.subheadline`) with line limits and minimumScaleFactor wrappers.
3. System Materials & Colors: Use `.regularMaterial` and semantic colors adapting properly between light and dark appearances.
4. Landscape HUD ergonomics: Mascot HUD anchored bottom-left; 3D room viewport unobstructed.
5. Headless Visual Audit: Run `./scripts/audit-ui.sh` to capture contrast screenshots across appearances and Dynamic Type tiers.
Refactor any violations and verify with `./scripts/verify.sh`.
```

---

## 🍳 Recipe 5: Zero-Miss Feature Delivery Protocol

### Objective
Ensure agents never miss a required step (ADR, tests first, verification, visual audit, automated changelog, clean atomic commits) when delivering new features or architectural capabilities.

### Prompt Template
```markdown
Execute the Zero-Miss Feature Delivery Protocol for [Feature/Capability Name]:
1. Spec & ADR: Create an ADR in `docs/adr/` if introducing an architectural contract, format, or schema boundary.
2. Tests First: Add Swift Testing assertions in `AlcoveTests` before or alongside implementation.
3. Implementation: Implement minimal clean code satisfying tests (enforcing `subdivisionScheme = "none"` on USD meshes and drywall boundary offsets).
4. Autonomous Verification: Run `./scripts/verify.sh` to confirm zero compilation or test errors.
5. Visual Audit: Run `./scripts/audit-ui.sh` to ensure visual contrast and layout symmetry on iPad landscape.
6. Automated Changelog: Run `./scripts/changelog.sh` to compile conventional commits—do NOT edit `CHANGELOG.md` manually.
7. Commit & Push: When instructed by the user, create distinct atomic commits using Conventional Commits with zero machine paths or raw file paths in commit messages, and push to the remote repository.
```

---

## 🚨 Emergency Circuit Breakers

If an agent ever encounters infinite loops or wandering behavior, paste one of these circuit breaker prompts:

### 🛑 Circuit Breaker 1: Infinite Test Loop Pause
```markdown
HALT TEST MODIFICATIONS. Do not modify the test assertions to make the suite pass. The test defines the contract. Re-read the requirements and fix only the implementation. Run `./scripts/verify.sh`.
```

### 🚨 Circuit Breaker 2: Multi-File Wandering Rollback
```markdown
STOP. You are touching unrelated files. Discard changes to everything except [target file], run `git status`, and run `./scripts/verify.sh`.
```
