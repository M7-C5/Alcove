---
name: code-review
description: Superpower skill for conducting an adversarial code review on git diffs, pull requests, or proposed Swift/SwiftUI/RealityKit changes before user presentation or merge.
---

# Superpower: Adversarial Code Review (Swift 6 / RealityKit / PR Gate)

Use this skill when reviewing git diffs or PRs to catch regressions, architectural drift, and platform traps.

## Review Checklist:

### 1. Project & Build Integrity
- **Shared Signing Protection**: Verify `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER` in `Alcove.xcodeproj/project.xcproj` were not overwritten by local personal Xcode settings.
- **PR Template & Changelogs**: Ensure PR descriptions follow `.github/pull_request_template.md`, Conventional Commits are used, and no raw file paths appear in commits or `CHANGELOG.md`.

### 2. Concurrency & SwiftData Boundaries
- **Actor & Sendable**: Confirm UI ViewModels/scenes are `@MainActor`, async/sensor callbacks extract immutable values across boundaries, and RealityKit `SceneEvents.Update` / escaping closures capture `[weak self]`.
- **Dual Layout Discipline (LP-011)**: Verify `baselineLayout` remains immutable and edits target `workingLayout` (or isolated value drafts before save).
- **Schema Safety**: New SwiftData fields on existing `@Model` classes must be optional (`Data? = nil`) or carry defaults for lightweight migration.

### 3. RealityKit & 3D Studio Consistency
- **Shared Builders**: Ensure 3D viewports reuse `ProceduralRoomShellBuilder` and `ProceduralFurnitureBuilder` rather than duplicating primitive box geometry.
- **Cutaway Shadow Stability**: Cutaway walls must use `OpacityComponent(opacity: 0.0)` (on iOS 18+) rather than `entity.isEnabled = false` so wall geometry stays in the shadow map depth pass.
- **Coordinates & Floor Clamping (LP-009)**: Right-handed coordinates ($+X$ right, $+Y$ up, $+Z$ viewer), floor at $Y = 0$, entities clamped within room bounds.

### 4. iPad Landscape UI & Design System
- **Touch Targets & Hit Testing**: All interactive controls provide $\ge 44 \times 44\text{pt}$ hit bounds (`48 \times 48\text{pt}` for primary HUD actions) and explicit `.contentShape(...)`.
- **Design Tokens & Typography**: New UI uses Light-only `Alcove*` color tokens and `SF Pro Rounded` / semantic Dynamic Type styles without `.position(x:y:)` layout traps (LP-008).

### 5. Verification
- Run `./scripts/verify.sh` on the PR/branch to confirm zero build errors/warnings, 100% test pass rate, and simulator shutdown.
