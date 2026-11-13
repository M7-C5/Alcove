# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add real-time collision highlights, top warning banner, and audit lock.
- Preserve multi-turn chat history and add zone occupancy context.
- Teach actionable interior design principles in stage evaluation tips.
- Implement SpatialFactVerifier to deterministically eliminate spatial hallucinations.
- Add smooth feathered screen-space overlay slider.
- Implement smooth 3D spatial overlay blend in identical orientation.
- Implement screen-space split curtain divider for before-after comparison.
- Add centered 3D before-after slider and room harmony scorecard.
- Cache stage evaluations until layout mutations occur with on-demand refresh.
- Ground Stage 1 evaluation in AI spatial situation diagnosis without lighting penalties.
- Expand companion chat window to responsive half-sheet.
- Add interactive light editing and Stage 4 AR placeholder.
- Streamline mascot companion bottom HUD and compact chat detents.
- Add multi-key failover pool and optimize Gemini 2.5 token usage.
- Add daylight-scrub micro-reactions and safe secret loader.
- Implement two-phase static intro and dynamic need dialogue curator.
- Add stage walkthrough overlay, markdown rendering, and model config sheet.
- Integrate Google Gemini service with quota fallback and guardrails.
- Implement anthropometric standards and fast-path circulation heuristics.
- Align sunlight preview with captured room compass.
- Refine selection dragging and sunlight controls.
- Add semantic color and shapestyle extensions.
- Add global alcove color palette assets.
- Implement mascot landing home screen and tactile pill button.
- Add dashboard route and decouple dashboard stack embedding.
- Import optimized home background art and cleanow font resources.
- Add temporary lighting playground shortcut.
- Add inline placement and interactive room simulation.
- Add ar walkthrough button to top toolbar and wire full screen presentation.
- Implement 1:1 life-size spatial walkthrough viewport and view model.
- Add ceiling cutaway evaluator and placement coordinate engine.
- Add point of view snap menu to top toolbar beside archive dock button.
- Implement ease-in-out orbit camera snapping and dynamic cutaway updates in viewport.
- Add architectural viewport presets for top, elevations, and reset angles.
- Wire archive inventory button and real-time 3D ghost raycast in studio view.
- Support floor raycasting and real-time 3D ghost placement in viewport.
- Add freeform furniture inventory dock supporting tap and drag restoration.
- Migrate viewport to native arview with sub-pixel projection and touch triage.
- Support incremental furniture rotation and position synchronization in view model.
- Implement circular sims action dial with gliding orbit rotation.
- Add furniture transform engine with boundary clamping and yaw snapping.
- Add full-height perimeter walls and dynamic camera-facing cutaways.
- Introduce wall cutaway evaluator for camera occlusion.
- Implement interactive RealityKit 3D viewport with room shell and sunlight.
- Add procedural multi-part furniture mesh builder.
- Add mock bedroom seed action to dashboard toolbar.
- Introduce mock bedroom and office generator with dual layouts.
- Implement value-based router and decoupled feature navigation.
- Enhance spatial models with lighting fixtures and preview containers.
- Add ipad landscape screen flow and mascot hud.
- Implement swiftdata domain models and mascot ai service.

### Changed

- Share view model warning severities with 3D viewport.
- Adopt global alcove color tokens in home and tactile pill.
- Unify color extensions to internal access level.
- Remove unused dashboard route and restore single stack ownership.
- Extract procedural room shell builder for multi-viewport reuse.
- Structure autonomous vertical slices with dedicated view models and components.

### Fixed

- Store API key in Keychain, use header auth, and decouple chat badge.
- Compute wall proximity from boundary extents and sanitize flowery placement wording.
- Generate room-aware dynamic recommendations naming active furniture.
- Replace textbook recommendations header with design tips.
- Serialize inward facing vectors and filter hallucinated orientation tips.
- Recognize task lighting companion pairs and exempt from walkway bottlenecks.
- Treat lamps and elevated lighting as natural surface companions without false bottlenecks.
- Restore shared team signing configuration.
- Constrain hero bounds, refine tactile pill shading, and add accessibility.
- Deduplicate font registration and release CoreText errors.
- Unify viewport geometry and restore AR access.
- Anchor sunlight to window opening and preserve shadows during wall cutaways.
- Replace solid window border with hollow casing and transparent glass.
- Update top architectural pov preset icon to horizontal top press.
- Replace arkit symbol with text label on top toolbar ar button.
- Update orbit hud icons to use clockwise rotate and archivebox.
- Configure camera usage description for arkit world tracking.
- Annotate MascotAIService and test suites with @MainActor for Swift 6.
- Resolve iPad interface orientations, bundle id, and app icon assets.

[Unreleased]: https://github.com/M7-C5/Alcove/tree/dev
