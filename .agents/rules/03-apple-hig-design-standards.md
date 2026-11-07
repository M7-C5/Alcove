# Apple Human Interface Guidelines (HIG) Standards

1. **iPad Landscape Native Form Factor**:
   - Alcove is designed landscape-first for iPad displays.
   - Anchor the Mascot HUD at the bottom-left with adjacent dialogue panel; ensure the 3D room above remains unobstructed and interactive.

2. **Touch Target Dimensions**:
   - Every tappable interactive control must have a minimum bounding frame of $44\times 44\text{pt}$ (preferably $48\times 48\text{pt}$ for primary HUD buttons).

3. **Dynamic Type & Typography**:
   - Use semantic typography (`.headline`, `.subheadline`, `.caption`) rather than hardcoded `.system(size:)` calls to ensure full accessibility.

4. **Sensory Feedback**:
   - Provide tactile haptic feedback on discrete milestones ($45^\circ$ angle snaps, stage completion, successful furniture placement).
