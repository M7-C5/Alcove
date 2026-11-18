# ADR-0004: Lighting Draft Editor and RealityKit Simulation

* Status: accepted
* Date: 2026-11-11

## Context and Problem Statement

Resign provides ceiling-plan placement, transient fixture editing, and a lighting simulation session. Alcove already persists Codable `LightFixture` values on each `Layout`, but its Illumination toolbar only adds lamps at the origin and its canvas draws symbolic light pools.

## Decision Outcome

Adapt the Resign interaction to `Features/Studio3D/Stages/Stage3_Illumination` using Alcove's existing fixture schema and meter-based coordinates.

* The main Illumination screen has bounded columns for **Your lights**, the room viewport, and **Lighting preview / Light settings**. Adaptive cream, peach, and brown color assets and rounded typography follow the lighting workspace design. Compact windows and accessibility text sizes use a vertically scrolling workspace. The companion is absent from this screen.
* Placement, lamp type, lumen output, and Kelvin edits operate on value drafts and preview immediately. **Save** explicitly encodes and saves the working layout, preserving fixture identities and restoring its previous data on failure. Saving an empty array removes the final lamp. Baseline and stale-layout edits are rejected.
* **Select** enters multiple selection. List rows and viewport taps toggle fixtures in a shared ID set; **Select all**, **Clear**, checkmarks, a count, and non-emitting model outlines make the selection visible. The inspector shows common values or **Mixed**, and changes only the property the user edits on selected drafts. Deletion confirms the number of selected lights. **Done** keeps the first selected fixture for single editing; placement exits multiple selection and selects only the newly placed fixture. Selection is transient and never marks the layout dirty by itself.
* **Add light** activates placement directly in the main viewport. A translucent white plane sits above room geometry; its height is also used for tap-ray intersection. Top view is locked and orbit, pinch, reset, and camera-preset controls are disabled while placing. **Done** removes the plane and restores the previous camera preset. No separate editor sheet is used.
* Everyday types (Desk Lamp, Standing Lamp, Table Lamp, Ceiling Light, Pendant Light, and Wall Light) choose elevation and lighting layer automatically. Users do not enter positions, heights, names, or technical layer categories. Existing saved fixtures without the optional Codable `kind` field remain readable. Warm/Cool and Dim/Bright labels accompany the two sliders.
* Simulation controls include camera presets, drag to orbit, pinch to zoom, double-tap to reset, a 24-hour clock, artificial-light switch, and neutral layout inspection in the camera menu. The master switch never overwrites individual saved lamp switches.
* Audit and Lighting use the same `StudioViewportActions` POV/AR buttons and `StudioOrbitCameraController`. The controller is extracted from the primary viewport: preset snaps retain its 350 ms easing, shortest yaw path, camera framing, projection and zoom bounds. Re-selecting a preset after orbiting snaps again. Placement temporarily fits and locks the top view, then restores the chosen preset and zoom.
* `Studio3DView` owns the single AR walkthrough presentation for all stages. Lighting requests that presentation through a callback and unmounts its non-AR viewport while AR is active, just as Audit does. Lighting has no separate AR presenter or session implementation.
* Room and furniture geometry is retained during live edits. Fixture entities are reconciled by identity, and clock and switch changes update existing lights. Leaving the renderer removes its scene anchors.
* Each lamp type has a distinct procedural 3D model, cloned from six cached prototypes. Desk and table lamps rest on tapped table or low cabinet surfaces, standing lamps rest on the floor, ceiling fixtures mount overhead, and wall lights face inward from the nearest wall. The placement layer displays these same models; returning to simulation restores their physical mounts.
* Emitters follow the model's lamp opening. Desk, ceiling, pendant, and wall lights use type-specific spot cones; standing and table lamps use diffuse point lights. Kelvin and lumen changes update the real light and luminous lens/shade materials without rebuilding geometry. A lamp switch disables both its illumination and material glow.
* The plan and preview share room bounds and wall/ceiling setbacks. Furniture is represented by dimensioned blocks. No persistence schema migration or new package is required.

The viewport has no visible grid points. In placement mode, tapping inside the white layer places a light at the ray-projected position, snapped to a hidden 5 cm grid with a 15 cm wall setback. Tapping an existing lamp selects it. The prompt reads “Tap where you want a light.” VoiceOver can activate placement and add a lamp at the center. Orbit uses the same horizontal drag direction as the furniture viewport, so the room follows the finger.

## Consequences and Limits

Alcove does not currently persist Resign's captured wall outlines, window apertures, geographic site, or north calibration. The room is a rectangular dollhouse and daylight follows an explicitly illustrative 08:00–20:00 arc, with darkness at night. The preview does not claim geographic accuracy or calibrated illuminance.

The dynamic-light budget follows the device GPU. Devices supporting Metal Apple GPU family 6 or later render all enabled fixtures instead of globally truncating the list to seven. Older devices render the brightest seven fixtures while sunlight is active, or eight when it is not; the simulation inspector explains this fallback when exceeded. Models reflect their saved on/off/brightness state independently of the fallback render selection. All saved fixtures remain available to the illumination evaluation. Device previews enable spot-light shadows; simulator previews omit those shadows for predictable rendering. Diffuse sources approximate shade transmission; the preview does not simulate material scattering or indirect light transport.

## Verification

`AlcoveTests/Features/Studio3D/Stages/LightingWorkspaceTests.swift` covers draft isolation, identity preservation, placement bounds, persistence and last-light deletion, missing-layout cloning, baseline protection, stale-layout rejection, night simulation, render selection, snapshot isolation, studio clock synchronization, camera navigation bounds, bounded column widths, floor-to-plan mapping, and live fixture reconciliation without rebuilding room meshes. Run `./scripts/verify.sh` for the build and full suite with simulator cleanup.

`AlcoveTests/Features/Studio3D/Stages/LightingFixtureModelTests.swift` covers distinct lamp geometry, collision selection, emitter alignment, mounting, placement restoration, focused/diffuse light selection, material glow, color and brightness changes, and fixture replacement and removal.

The workspace suite also covers additive selection and deselection, mixed settings, independent batch property edits, unique names when changing kinds, batch save/deletion with baseline preservation, placement isolation, and viewport selection outlines.

### Lighting review follow-up

The compact tactile button retains Dynamic Type for its label and scales its geometry using the title text style. Both appearances use generated Alcove semantic color tokens; the cream surface uses `alcoveSurfaceElevated`. The regular button preserves the existing Home label, capsule layers, sizing and press feedback. Extending this shared component and adding MainBackground are required by the Lighting design; Home continues using its existing background and regular button.

The visually open lighting mockup also contains a permanent, nearly transparent ceiling shadow occluder built from the shared ceiling geometry. It extends to the exterior wall edges, stays active through camera cutaways and blocks direct overhead sunlight while leaving the window aperture open. Its opacity follows the existing wall-cutaway convention. Device rendering must confirm the shadow result; simulator geometry tests verify coverage and persistence, not GPU shadow output.


### Shared studio chrome and floor north

Lighting and the other studio stages reuse a 32pt Cleanow title, 40pt five-step progress dots, 44pt tactile navigation pills, 45pt camera/AR buttons and the same camera-menu content. Lighting inspector headings use the catalog's 20pt Cleanow style, semantic Alcove surfaces and 2.5pt panel outlines. Feature-specific controls and callbacks stay in their respective workspaces.

North is a room-space floor decal with an unlit arrow, label and translucent cream backing. Its initial corner is chosen to reduce overlap with furniture footprints. It does not cast shadows or add collision targets, and orbit/zoom never changes its compass bearing. Uncaptured rooms show N? for the existing sample orientation.
