---
name: ui-audit
description: Superpower skill for inspecting and enforcing SwiftUI layout ergonomics, Apple HIG compliance, Dynamic Type, and contrast symmetry for iPad landscape form factor.
---

# Superpower: Apple HIG & iPad Landscape UI Audit

Use this skill when auditing or refining UI components to ensure strict compliance with Apple Human Interface Guidelines and iPad landscape ergonomics established in `.agents/rules/03-apple-hig-design-standards.md`.

## Active Audit Protocol:

### 1. iPad Landscape Ergonomics & Layout
- **Landscape-First Alignment**: Verify layouts are optimized specifically for iPad landscape viewing (`.landscapeLeft`, `.landscapeRight`).
- **HUD Positioning**: Ensure the Mascot HUD is anchored in the bottom-left corner with adjacent dialogue bubble, keeping the central 3D viewport completely unobstructed for manipulation.
- **Layout Expansion Traps (LP-008)**: Flag any usage of `.position(x:y:)` which greedily expands frame boundaries. Use `.offset()` or `ZStack(alignment:)` instead.
- **Safe Area Insets**: Confirm bottom HUD controls respect the iPad Home Indicator safe area margins.

### 2. Touch Target Dimensions & Hit Testing
- **Minimum Hit Bounds**: Check every interactive element, Mascot icon, button, and stage selection card against the $44 \times 44\text{pt}$ minimum hit target ($48 \times 48\text{pt}$ preferred for primary HUD actions).
- **Hit Masking**: Ensure custom tappable views and containers use `.contentShape(Rectangle())` so whitespace between text and icons remains responsive to taps.

### 3. Dynamic Type & Typography
- **Prohibition on Hardcoded Sizing**: Search and eliminate hardcoded `.system(size:)` calls in standard views. Mandate semantic styles (`.largeTitle`, `.title2`, `.headline`, `.subheadline`, `.caption`).
- **Text Truncation Defense**: Verify that HUD status badges, scorecards, and dialogue text accommodate larger text scales using `minimumScaleFactor` or multiline text limits where appropriate.

### 4. Color Symmetry & Contrast
- **Prohibition on Raw Black/White**: Flag hardcoded `.white` or `.black` text and backgrounds in UI views.
- **Symmetric Appearance**: Verify views adapt seamlessly between Dark Mode and Light Mode using semantic system colors (`Color(uiColor: .systemBackground)`, `.secondarySystemBackground`, `Color.primary`, `Color.secondary`).
- **Contrast Ratios**: Enforce WCAG AA contrast symmetry (4.5:1 for standard text, 3.0:1 for large text/icons).

### 5. Tactile Feedback & Haptics
- **Discrete Milestones**: Confirm sensory haptic feedback is triggered on rotational snaps ($45^\circ$), successful placement, and stage completion.
