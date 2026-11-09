# Apple Human Interface Guidelines (HIG) & SwiftUI Design Standards

This rule governs all SwiftUI UI, layout, typography, and styling decisions within Alcove to ensure premier visual polish, accessibility, and native Apple feel on iPad landscape displays.

---

## 1. iPad Landscape Form Factor & HUD Ergonomics

- **Landscape-First Alignment**: Alcove is built native landscape-first for iPad displays. Keep interface orientation locked to landscape.
- **Mascot HUD Placement**: Anchor the Mascot HUD at the bottom-left with an adjacent dialogue overlay panel. Ensure the 3D room viewport remains unobstructed and interactive.
- **Safe Area Insets**: Never clip actionable controls or text into screen edges, rounded display corners, or navigation bars. Use `.safeAreaPadding()` or explicit margins.

---

## 2. Spacing Grid, Surfaces & Container Tokens

- **Standard 8pt Spacing Grid**: Adhere strictly to Apple's 8pt spatial grid:
  - Small / compact spacing: 8 pt
  - Standard spacing: 16 pt
  - Section / card spacing: 24–32 pt
- **Container Tokens & Materials**: Use native grouped surfaces with continuous curvature:
  ```swift
  .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  ```
  Card panels, HUD bars, and sheet surfaces should use `.continuous` corner styling to blend seamlessly into iPadOS squircle aesthetics.

---

## 3. Touch Targets & Interaction Geometry

- **Minimum Hit Target**: Every tappable interactive control must maintain a minimum bounding frame of **44 × 44 pt** (`.frame(minWidth: 44, minHeight: 44)` or `.contentShape(Rectangle())`).
- **Primary HUD Actions**: Primary Mascot HUD buttons and stage navigation triggers should prefer **48 × 48 pt** hit targets for comfortable thumb-driven iPad interaction.

---

## 4. Dynamic Type & Typography Hierarchy

- **Semantic Text Styles**: Always use semantic system fonts (`.largeTitle`, `.title`, `.headline`, `.body`, `.subheadline`, `.caption`) rather than hardcoded point sizes (`.font(.system(size: 14))`). Fixed sizes break accessibility when users adjust Dynamic Type scaling.
- **Multilingual & Dynamic Type Wrappers**: Allow labels and Mascot dialogue text to adaptively wrap or scale rather than clipping:
  ```swift
  Text(mascotDialogue)
      .font(.subheadline)
      .lineLimit(3)
      .minimumScaleFactor(0.85)
  ```

---

## 5. Dark Mode & High Contrast Symmetry

- **Semantic Colors**: Use semantic system colors (`Color.primary`, `Color.secondary`, `Color(uiColor: .systemBackground)`, `Color(uiColor: .secondarySystemGroupedBackground)`) instead of hardcoded hex values or literal `.black` / `.white`.
- **SF Symbols**: Use Apple's SF Symbols with semantic weights and hierarchical rendering:
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
