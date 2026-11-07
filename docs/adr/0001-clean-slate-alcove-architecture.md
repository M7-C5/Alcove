# ADR-0001: Clean-Slate Architecture for Gamified Educational iPad App

* Status: accepted
* Deciders: Engineering & Product Team
* Date: 2026-11-08

## Context and Problem Statement

Following the completion of the `Resign` exploration project, the product vision pivoted significantly toward an educational, gamified interior design curriculum natively optimized for iPad landscape. The existing codebase contained legacy assumptions (portrait-first phone views, flat room editing, non-curriculum state models) that would create high friction and technical debt if retrofitted.

We needed a clean architecture tailored specifically for:
1. Native iPad landscape HUD with visual-novel RPG aesthetics.
2. A progressive 4-stage pedagogical curriculum per scanned room.
3. An interactive Mascot AI companion with sub-100ms micro-reactions and advisory stage gates.
4. Dual layout model preserving the original baseline scan alongside mutable drafts.

## Decision Drivers

* Clean domain modeling without legacy technical debt.
* Native iPad ergonomics and visual novel UI conventions.
* Deterministic testability and offline previewing for AI services.
* Uncompromised user autonomy during gamified stage progression.

## Considered Options

1. **Refactor Existing Resign Codebase**: Migrate existing views, models, and layout managers.
2. **Clean-Slate Architecture (Alcove)**: Build fresh SwiftData models, RealityKit viewports, and Mascot AI services purposefully designed for the new vision.

## Decision Outcome

Chosen option: **Option 2: Clean-Slate Architecture (Alcove)**, because:
* Legacy assumptions in `Resign` would require extensive structural surgery and risk latent regressions.
* Designing from scratch allows Swift 6 strict concurrency, modern SwiftData relationships, and an iPad landscape HUD layout from day one.
* The 4-stage curriculum and dual layout architecture require distinct first-class domain entities.

### Positive Consequences

* Streamlined SwiftData schema (`Room`, `Layout`, `Furniture`, `StageProgress`).
* Clean separation of concerns between local fast-path heuristics (<100ms) and remote LLM evaluations.
* Clear visual novel RPG interface design tailored specifically for iPad landscape.
* Instant testability with mock services and deterministic fixtures.

### Negative Consequences

* Initial setup time to recreate base RealityKit viewports and camera controls.
