# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

- Structure autonomous vertical slices with dedicated view models and components.

### Fixed

- Annotate MascotAIService and test suites with @MainActor for Swift 6.
- Resolve iPad interface orientations, bundle id, and app icon assets.

[Unreleased]: https://github.com/M7-C5/Alcove/tree/dev
