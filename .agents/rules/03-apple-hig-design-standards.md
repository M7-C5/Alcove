# Apple Human Interface Guidelines (HIG) & Alcove Design Standards

This rule governs SwiftUI UI, layout, typography, and styling decisions within Alcove to ensure native iPad landscape ergonomics, accessibility, and visual consistency.

---

## 1. iPad Landscape Form Factor & HUD Ergonomics

- **Landscape-First Alignment**: Alcove is built native landscape-first for iPad displays. Keep interface orientation locked to landscape.
- **Unobstructed 3D Viewport**: Keep overlays, toolbars, and Mascot HUD panels docked cleanly at the edges/corners so the central 3D room viewport remains unobstructed and interactive.
- **Safe Area Insets**: Never clip actionable controls or text into screen edges, rounded display corners, or navigation bars. Use `.safeAreaPadding()` or explicit margins.

---

## 2. Spacing Grid, Surfaces & Container Tokens

- **Standard 8pt Spacing Grid**: Adhere strictly to Apple's 8pt spatial grid:
  - Small / compact spacing: `8 pt`
  - Standard spacing: `16 pt`
  - Section / card spacing: `24–32 pt`
- **Container Curvature**: Use `.continuous` corner styling (`RoundedRectangle(cornerRadius: ..., style: .continuous)`) on cards, containers, and HUD surfaces.

---

## 3. Touch Targets & Interaction Geometry

- **Minimum Hit Target**: Every tappable interactive control must maintain a minimum bounding frame of **44 × 44 pt** (`.frame(minWidth: 44, minHeight: 44)` or `.contentShape(Rectangle())`).
- **Primary HUD Actions**: Primary HUD buttons and stage navigation triggers should prefer **48 × 48 pt** hit targets for comfortable thumb-driven iPad interaction.

---

## 4. Typography & Dynamic Type

- **Font Family**: Use `SF Pro Rounded` (`.system(..., design: .rounded)`) with semantic text styles (`.largeTitle`, `.title2`, `.headline`, `.subheadline`, `.caption`) so text scales cleanly with Dynamic Type.
- **Wrapping & Scaling**: Allow labels and Mascot dialogue text to wrap or scale rather than clipping (`minimumScaleFactor(0.85)`, `fixedSize(horizontal: false, vertical: true)`).

---

## 5. Light-Only Global Color System & Contrast

- **Light-Only Palette**: Alcove does not support Dark Mode. Use the global `Alcove*` semantic color tokens in `Assets.xcassets` / `Alcove/UI/Colors.swift` (e.g., `.alcoveInk` `#6D4531` for text/borders, `.alcoveBackground` `#FEF6ED` for backgrounds, `.alcoveSurface` `#FEEEDE` for containers/alerts, `.alcovePrimaryFill` `#FBD460` for primary actions) rather than hardcoded inline hex values or Dark Mode system backgrounds.
- **SF Symbols**: Use Apple's SF Symbols with semantic weights and hierarchical rendering where appropriate:
  ```swift
  Image(systemName: "cube.fill")
      .symbolRenderingMode(.hierarchical)
  ```

---

## 6. Haptics & Sensory Feedback

- Provide tactile haptic feedback on discrete milestones ($45^\circ$ angle snaps, stage completion, successful furniture placement):
  ```swift
  .sensoryFeedback(.impact(weight: .light), trigger: isActionCompleted)
  ```
