---
name: scaffold-module
description: Protocol for scaffolding a new Swift/SwiftUI feature or domain module following strict interface, testing, and implementation separation adapted for Alcove's vertical slice architecture.
---

# Scaffold Module Skill (Swift / SwiftUI / SwiftData)

Use this skill when introducing a new feature slice or domain module to ensure contract-first development, pure domain isolation, and architectural consistency with Alcove's vertical slice architecture.

## Alcove Architectural Boundaries

- **`Core/Models/`**: SwiftData `@Model` entities (`Room`, `Layout`, `Furniture`, `StageProgress`) and value-type spatial models.
- **`Core/Services/`**: Domain engines and actor-isolated service contracts conforming to `Sendable` (e.g., `MascotAIServiceProtocol`, `FastPathRulebook`).
- **`Features/<Slice>/`**: Autonomous vertical slices (`Dashboard`, `Stages`, `Studio3D`, `MascotChat`) containing `@Observable @MainActor` view models and declarative SwiftUI views.
- **`AlcoveTests/`**: Swift Testing suites validating domain invariants before UI wiring.

---

## 5-Step Scaffolding Procedure:

### Step 1: Model & Schema Definition (`Core/Models/`)
Define domain entities or SwiftData schemas with explicit defaults and value decoupling:
```swift
import Foundation
import SwiftData

@Model
final class FeatureEntity {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
```

### Step 2: Protocol Contracts (`Core/Services/`)
Define service protocols isolating side effects and enforcing `Sendable` concurrency boundaries:
```swift
import Foundation

protocol FeatureServiceProtocol: Sendable {
    func evaluateFeatureState() async throws -> Bool
}
```

### Step 3: Test Scaffolding (`AlcoveTests/`)
Write unit tests using Swift Testing verifying domain invariants, fast-path heuristics, or in-memory SwiftData containers *before* writing UI:
```swift
import Testing
import SwiftData
@testable import Alcove

@Suite("Feature Domain Tests")
struct FeatureDomainTests {
    @Test func featureStateValidation() async throws {
        let entity = FeatureEntity(name: "Test Node")
        #expect(entity.name == "Test Node")
    }
}
```

### Step 4: UI & ViewModel Implementation (`Features/<FeatureName>/`)
Implement `@Observable` `@MainActor` view models and declarative SwiftUI views:
```swift
import SwiftUI
import Observation

@Observable
@MainActor
final class FeatureViewModel {
    var items: [FeatureEntity] = []
    private let service: any FeatureServiceProtocol

    init(service: any FeatureServiceProtocol) {
        self.service = service
    }
}

struct FeatureView: View {
    @State private var viewModel: FeatureViewModel

    init(viewModel: FeatureViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack {
            // Declarative UI
        }
    }
}
```

### Step 5: Verification Gate
Run `./scripts/verify.sh` to ensure clean build, zero compiler warnings, 100% test pass rate, and automatic thermal cleanup before declaring completion.
