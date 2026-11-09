# Changelog

All notable changes to **Alcove** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- feat(ui): add ipad landscape screen flow and mascot hud (ec746bc)
- feat(core): implement swiftdata domain models and mascot ai service (2c39a28)

### Fixed
- fix(concurrency): annotate MascotAIService and test suites with @MainActor for Swift 6 (ac749bd)
- fix(build): resolve iPad interface orientations, bundle id, and app icon assets (e5946cb)

### Documentation
- docs(playbook): add agentic development playbook and architectural recipes (0dd751c)
- docs(rules): update autonomous directives and apple engineering standards (64629de)
- docs(architecture): add project documentation and ADR-0001 (c0645bc)

### Tooling & Maintenance
- chore(agents): add specialized domain skills for review and auditing (911fa16)
- chore(build): normalize application project configuration (ca59382)
- chore(tooling): add automated verification, ui audit, and hook installation scripts (6d69694)
- ci(xcodecloud): track xcode cloud target manifest and dynamic test runner (ea96d70)
- test(core): add unit tests for stage progression, layout reset, and mascot heuristics (b9595e3)
- chore(xcode): configure ipad landscape orientation and shared test scheme (94f9ff0)
- chore(tooling): add automated verification and changelog scripts (6d8e2f1)
- chore(repo): initialize repository configuration and agentic guidelines (0e1ae60)

