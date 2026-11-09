# Changelog

All notable changes to **Alcove** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
- docs(changelog): update automated release notes (98b5d89)
- docs(playbook): add agentic development playbook and architectural recipes (0dd751c)
- docs(rules): update autonomous directives and apple engineering standards (64629de)
- docs(architecture): add project documentation and ADR-0001 (c0645bc)

### Tooling & Maintenance
- ci(workflows): remove legacy runner configuration in favor of xcode cloud (c3a1099)
- chore(agents): add specialized domain skills for review and auditing (911fa16)
- chore(build): normalize application project configuration (ca59382)
- chore(tooling): add automated verification, ui audit, and hook installation scripts (6d69694)
- ci(xcodecloud): track xcode cloud target manifest and dynamic test runner (ea96d70)
- test(core): add unit tests for stage progression, layout reset, and mascot heuristics (b9595e3)
- chore(xcode): configure ipad landscape orientation and shared test scheme (94f9ff0)
- chore(tooling): add automated verification and changelog scripts (6d8e2f1)
- chore(repo): initialize repository configuration and agentic guidelines (0e1ae60)

