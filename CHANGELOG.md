# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

- Extract procedural room shell builder for multi-viewport reuse.
- Structure autonomous vertical slices with dedicated view models and components.

### Fixed

- Replace arkit symbol with text label on top toolbar ar button.
- Update orbit hud icons to use clockwise rotate and archivebox.
- Configure camera usage description for arkit world tracking.
- Annotate MascotAIService and test suites with @MainActor for Swift 6.
- Resolve iPad interface orientations, bundle id, and app icon assets.

[Unreleased]: https://github.com/M7-C5/Alcove/tree/dev
