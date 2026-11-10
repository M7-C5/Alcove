# Changelog

All notable changes to **Alcove** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- feat(studio): add point of view snap menu to top toolbar beside archive dock button (83a0810)
- feat(studio): implement ease-in-out orbit camera snapping and dynamic cutaway updates in viewport (bbe75c8)
- feat(studio): add architectural viewport presets for top, elevations, and reset angles (7a40e43)
- feat(studio): wire archive inventory button and real-time 3D ghost raycast in studio view (b6113fb)
- feat(studio): support floor raycasting and real-time 3D ghost placement in viewport (b73b620)
- feat(studio): add freeform furniture inventory dock supporting tap and drag restoration (e0b261b)
- feat(studio): migrate viewport to native arview with sub-pixel projection and touch triage (ff51f9e)
- feat(studio): support incremental furniture rotation and position synchronization in view model (0788a44)
- feat(studio): implement circular sims action dial with gliding orbit rotation (9cec259)
- feat(studio): add furniture transform engine with boundary clamping and yaw snapping (4c3a696)
- feat(studio): add full-height perimeter walls and dynamic camera-facing cutaways (ee891d7)
- feat(studio): introduce wall cutaway evaluator for camera occlusion (cd2da61)
- feat(studio): implement interactive RealityKit 3D viewport with room shell and sunlight (8580c34)
- feat(studio): add procedural multi-part furniture mesh builder (339ffb7)
- feat(dashboard): add mock bedroom seed action to dashboard toolbar (7a41af8)
- feat(core): introduce mock bedroom and office generator with dual layouts (368862a)
- feat(navigation): implement value-based router and decoupled feature navigation (47c81d0)
- feat(core): enhance spatial models with lighting fixtures and preview containers (c2309c7)
- feat(ui): add ipad landscape screen flow and mascot hud (ec746bc)
- feat(core): implement swiftdata domain models and mascot ai service (2c39a28)

### Changed
- refactor(slices): structure autonomous vertical slices with dedicated view models and components (5418e67)

### Fixed
- fix(concurrency): annotate MascotAIService and test suites with @MainActor for Swift 6 (ac749bd)
- fix(build): resolve iPad interface orientations, bundle id, and app icon assets (e5946cb)

### Documentation
- docs(changelog): update automated release notes (7980a8d)
- docs(changelog): update automated release notes (f04fdf6)
- docs(agents): streamline repository guidelines to project-specific invariants (1364c2e)
- docs(architecture): record vertical slice architecture and simulation contracts (2a90b81)
- docs(changelog): update automated release notes (98b5d89)
- docs(playbook): add agentic development playbook and architectural recipes (0dd751c)
- docs(rules): update autonomous directives and apple engineering standards (64629de)
- docs(architecture): add project documentation and ADR-0001 (c0645bc)

### Tooling & Maintenance
- test(studio): add unit tests for camera presets, wall cutaways, and snap closure bindings (1521be4)
- test(studio): add unit tests for inventory archiving and restoration (7efc8ae)
- ci(workflows): remove legacy runner configuration in favor of xcode cloud (c3a1099)
- chore(agents): add specialized domain skills for review and auditing (911fa16)
- chore(build): normalize application project configuration (ca59382)
- chore(tooling): add automated verification, ui audit, and hook installation scripts (6d69694)
- ci(xcodecloud): track xcode cloud target manifest and dynamic test runner (ea96d70)
- test(core): add unit tests for stage progression, layout reset, and mascot heuristics (b9595e3)
- chore(xcode): configure ipad landscape orientation and shared test scheme (94f9ff0)
- chore(tooling): add automated verification and changelog scripts (6d8e2f1)
- chore(repo): initialize repository configuration and agentic guidelines (0e1ae60)

