---
name: security-audit
description: Superpower skill for scanning iOS app boundaries, entitlements, Keychain storage, and SwiftData local persistence security.
---

# Superpower: iOS Security & Perimeter Audit

Use this skill when auditing app entitlements, hardware capabilities, SwiftData local persistence security, and user data privacy in Alcove.

## Security Checklist:

### 1. SwiftData & Local Data Security
- **File Protection**: Ensure the SQLite store backing SwiftData uses `FileProtectionType.complete` so user floorplans and room models are encrypted at rest when the iPad is locked.
- **On-Device Data Boundary**: Confirm user-scanned floorplans, room geometry, furniture placements, and Mascot dialogues stay strictly on-device unless explicitly exported by the user.
- **Keychain vs Storage**: Verify that any authentication credentials, API keys, or security tokens are kept in Keychain (`kSecClassGenericPassword`) rather than SwiftData models or `UserDefaults`.

### 2. Entitlements & Hardware Permissions
- **Camera & LiDAR Scopes**: Ensure `NSCameraUsageDescription` in `Info.plist` accurately and clearly explains LiDAR room scanning and RoomPlan capture without misleading text.
- **Entitlement Minimization**: Confirm the app requests only essential entitlements; flag any unused capabilities or permissions in the project build configuration.

### 3. App Transport Security (ATS) & Network Isolation
- **ATS Strict Defaults**: Ensure `Info.plist` does not declare `NSAllowsArbitraryLoads` or broad domain exemptions.
- **Remote Service Isolation**: Mascot fast-path micro-reactions must execute entirely locally (LP-012) without unvetted outbound network traffic.

### 4. Diagnostic Logging & Privacy Hygiene
- **PII & Spatial Sanitization**: Ensure raw room coordinates, user dimensions, or conversational inputs are never dumped into console logs via `print()` or unredacted `os.Logger` statements in production code.
- **Sample Data Isolation**: Verify sample rooms and seed assets in `Core/Storage/SampleData.swift` contain only generic, non-personal reference layouts.
