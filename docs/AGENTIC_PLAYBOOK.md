# The Agentic Software Engineering Playbook (iPad & Alcove Edition)

This playbook outlines how autonomous AI agents collaborate on the **Alcove** iPadOS project.

---

## 1. Context Hierarchy & Progressive Disclosure

```
                       +------------------------------------------+
                       |  5. Progressive Superpowers & Skills     |
                       |     (.agents/skills/*)                   |
                       +------------------------------------------+
                       |  4. Living Swift Protocols & Schemas     |
                       |     (SwiftData @Model, Domain Protocols) |
                       +------------------------------------------+
                       |  3. Autonomous Self-Verification Loop    |
                       |     (./scripts/verify.sh & Thermal Trap) |
                       +------------------------------------------+
                       |  2. Modular Progressive Rules            |
                       |     (.agents/rules/*)                    |
                       +------------------------------------------+
                       |  1. Root Constitution & Safety Bounds    |
                       |     (AGENTS.md, Git Discipline)          |
                       +------------------------------------------+
                                 AGENT CONTEXT PYRAMID
```

In accordance with progressive disclosure:
- Agents consult `AGENTS.md` for overarching repository invariants.
- Rules in `.agents/rules/` are loaded on demand based on domain activity (verification, architecture, HIG, or post-mortem patterns).
- Superpower skills in `.agents/skills/` are invoked when specialized audits or scaffolding are required.

---

## 2. Core Axioms for Alcove Agentic Development

### 1. Sub-Second Test Partitioning & Thermal Cleanup
- Compiling and executing unit tests (`AlcoveTests`) takes ~2–4 seconds in headless mode.
- Simulators consume substantial background CPU and battery budget if left active.
- Every automated run terminates background simulator processes upon completion:
  ```bash
  xcrun simctl shutdown all 2>/dev/null || true
  ```
- Fast verification is strictly executed via `./scripts/verify.sh`.

### 2. Strict Git Discipline
- Agents **never** run `git commit` without explicit permission from the developer.
- Every commit must be atomic and follow Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`).
- Commit messages and changelog entries must NEVER contain machine-specific absolute paths or raw file paths (e.g. `foo.swift`). Use domain concepts and component names.

### 3. Four-Stage Pedagogical Curriculum Architecture
Alcove teaches interior design through a structured four-stage curriculum:
1. **Stage 1: The Audit**: Spatial analysis, natural lighting orientation, bottleneck identification (<60cm clearance).
2. **Stage 2: The Rearrangement**: Furniture layout, focal alignment, $45^\circ$ snap dial, inventory management.
3. **Stage 3: The Illumination**: Daylight scrubber (8 AM – 8 PM simulation) and multi-layered artificial lighting.
4. **Stage 4: The Harmony Reveal**: Interactive Before/After split comparison, comprehensive room scorecard, AR preview.
- **Advisory Gate Invariant**: Evaluation gates provide clear critiques and recommendations, but **must permanently provide a `"Proceed Anyway"` option** to preserve user creative autonomy.

### 4. Mascot Companion Architecture
The Mascot companion operates on a two-tier latency model:
1. **Fast-Path Rulebook (`< 100ms`)**: Pure local heuristics responding immediately to furniture gestures, rotation snaps, and clearance violations with floating reaction bubbles.
2. **Asynchronous LLM Engine**: Engaged on demand for stage evaluations and open conversational chat in the contextual drawer.

### 5. Dual Layout Preservation
To enable consequence-free experimentation:
- `baselineLayout`: Immutable snapshot of the raw room scan. Never overwritten during user editing.
- `workingLayout`: Mutable draft where furniture moves, lighting changes, and stylistic iterations live.
- Powers the Stage 4 Before/After split slider and instant "Reset to Original" capability.

### 6. Multimodal Visual & Adversarial Verification
- Before presenting UI changes or declaring milestones complete, agents verify visual contrast, Dynamic Type scaling, and layout symmetry via `./scripts/audit-ui.sh`.
- Adversarial review is conducted via the `code-review` skill to catch concurrency data races, retain cycles, and HIG violations.

---

## 3. Developer & Agent Command Quick Reference

| Action | Command | Purpose |
| :--- | :--- | :--- |
| **Fast Verification** | `./scripts/verify.sh` | Compiles scheme + runs Swift unit tests with thermal cleanup |
| **Visual UI Audit** | `./scripts/audit-ui.sh` | Captures headless iPad screenshots across appearances & Dynamic Type |
| **Changelog Generator** | `./scripts/changelog.sh` | Compiles conventional commits into `CHANGELOG.md` |
| **Install Git Hooks** | `./scripts/install-hooks.sh` | Configures git hooks for Conventional Commits & path protection |
| **Build Only** | `xcodebuild build -scheme Alcove -destination "generic/platform=iOS Simulator"` | Immediate syntax & type checking |

---

## 4. Emergency Circuit Breakers

If an agent ever encounters unexpected loops or wandering behavior, invoke these standardized circuit breakers:

### 🛑 Circuit Breaker 1: Infinite Test Loop Pause
```markdown
HALT TEST MODIFICATIONS. Do not modify the test assertions to make the suite pass. The test defines the contract. Re-read the requirements and fix only the implementation. Run `./scripts/verify.sh`.
```

### 🚨 Circuit Breaker 2: Multi-File Wandering Rollback
```markdown
STOP. You are touching unrelated files. Discard changes to everything except [target file], run `git status`, and run `./scripts/verify.sh`.
```

### 🔄 Circuit Breaker 3: Simulator / Canvas State Recovery
If simulator or SwiftUI Canvas rendering hangs or encounters datastore deadlocks:
1. Shut down all simulator instances: `xcrun simctl shutdown all`.
2. Clear temporary simulator application support or run `./scripts/verify.sh`.
3. Avoid erasing all global simulator data as a first step; verify project compilation cleanly first.
