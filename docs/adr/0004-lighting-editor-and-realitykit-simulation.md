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
* Room and furniture geometry is retained during live edits. Fixture entities are reconciled by identity, and clock and switch changes update existing lights. Leaving the renderer removes its scene anchors.
* Each lamp type has a distinct procedural 3D model, cloned from six cached prototypes. Desk and table lamps rest on tapped table or low cabinet surfaces, standing lamps rest on the floor, ceiling fixtures mount overhead, and wall lights face inward from the nearest wall. The placement layer displays these same models; returning to simulation restores their physical mounts.
* Emitters follow the model's lamp opening. Desk, ceiling, pendant, and wall lights use type-specific spot cones; standing and table lamps use diffuse point lights. Kelvin and lumen changes update the real light and luminous lens/shade materials without rebuilding geometry. A lamp switch disables both its illumination and material glow.
* The plan and preview share room bounds and wall/ceiling setbacks. Furniture is represented by dimensioned blocks. No persistence schema migration or new package is required.

The viewport has no visible grid points. In placement mode, tapping inside the white layer places a light at the ray-projected position, snapped to a hidden 5 cm grid with a 15 cm wall setback. Tapping an existing lamp selects it. The prompt reads “Tap where you want a light.” VoiceOver can activate placement and add a lamp at the center. Orbit uses the same horizontal drag direction as the furniture viewport, so the room follows the finger.

## Consequences and Limits

Alcove does not currently persist Resign's captured wall outlines, window apertures, geographic site, or north calibration. The room is a rectangular dollhouse and daylight follows an explicitly illustrative 08:00–20:00 arc, with darkness at night. The preview does not claim geographic accuracy or calibrated illuminance.

RealityKit's dynamic-light budget reserves one light for the sun and renders the seven brightest enabled fixtures. All saved fixtures retain visible models and remain available to the illumination evaluation. The simulation inspector explains the limit when exceeded. Device previews enable spot-light shadows; simulator previews omit those shadows for predictable rendering. Diffuse sources approximate shade transmission; the preview does not simulate material scattering or indirect light transport.

## Verification

`AlcoveTests/Features/Studio3D/Stages/LightingWorkspaceTests.swift` covers draft isolation, identity preservation, placement bounds, persistence and last-light deletion, missing-layout cloning, baseline protection, stale-layout rejection, night simulation, render selection, snapshot isolation, studio clock synchronization, camera navigation bounds, bounded column widths, floor-to-plan mapping, and live fixture reconciliation without rebuilding room meshes. Run `./scripts/verify.sh` for the build and full suite with simulator cleanup.

`AlcoveTests/Features/Studio3D/Stages/LightingFixtureModelTests.swift` covers distinct lamp geometry, collision selection, emitter alignment, mounting, placement restoration, focused/diffuse light selection, material glow, color and brightness changes, and fixture replacement and removal.

The workspace suite also covers additive selection and deselection, mixed settings, independent batch property edits, unique names when changing kinds, batch save/deletion with baseline preservation, placement isolation, and viewport selection outlines.
