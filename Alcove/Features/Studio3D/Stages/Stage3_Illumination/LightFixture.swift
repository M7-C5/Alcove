import Foundation

/// Everyday fixture names; mounting height and lighting layer are chosen automatically.
public enum LightKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case ceilingLight, pendantLight, deskLamp, standingLamp, tableLamp, wallLight

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ceilingLight: return "Ceiling Light"
        case .pendantLight: return "Pendant Light"
        case .deskLamp: return "Desk Lamp"
        case .standingLamp: return "Standing Lamp"
        case .tableLamp: return "Table Lamp"
        case .wallLight: return "Wall Light"
        }
    }

    public var icon: String {
        switch self {
        case .ceilingLight: return "light.ceiling.fill"
        case .pendantLight: return "light.pendant.fill"
        case .deskLamp: return "lamp.desk.fill"
        case .standingLamp: return "lamp.floor.fill"
        case .tableLamp: return "lamp.table.fill"
        case .wallLight: return "light.wall.fill"
        }
    }

    public var layer: LightLayer {
        switch self {
        case .ceilingLight, .pendantLight: return .ambient
        case .deskLamp, .standingLamp, .tableLamp: return .task
        case .wallLight: return .accent
        }
    }

    func elevation(roomHeight: Double) -> Double {
        let height: Double
        switch self {
        case .ceilingLight: height = roomHeight - 0.08
        case .pendantLight: height = roomHeight - 0.6
        case .deskLamp: height = 0.85
        case .standingLamp: height = 1.6
        case .tableLamp: height = 0.65
        case .wallLight: height = 1.8
        }
        return min(max(0.05, roomHeight - 0.08), max(0.05, height))
    }
}

/// Architectural interior lighting layers according to standard illumination practices.
public enum LightLayer: String, Codable, CaseIterable, Sendable, Identifiable {
    case daylight
    case ambient
    case task
    case accent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .daylight: return "Daylight"
        case .ambient: return "Ambient Fill"
        case .task: return "Task Lighting"
        case .accent: return "Accent & Mood"
        }
    }

    public var icon: String {
        switch self {
        case .daylight: return "sun.max.fill"
        case .ambient: return "light.recessed.fill"
        case .task: return "lamp.desk.fill"
        case .accent: return "light.ribbon.fill"
        }
    }

    public var recommendedKelvin: Int {
        switch self {
        case .daylight: return 5500
        case .ambient: return 3000
        case .task: return 4000
        case .accent: return 2700
        }
    }
}

/// Simulated physical light fixture placed inside a room layout.
public struct LightFixture: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var layer: LightLayer
    public var positionX: Double
    public var positionZ: Double
    public var elevationY: Double
    public var lumens: Double
    public var colorTemperatureKelvin: Int
    public var isOn: Bool
    public var kind: LightKind?

    public var resolvedKind: LightKind {
        if let kind { return kind }
        if layer == .accent { return .wallLight }
        if layer == .task {
            let name = name.lowercased()
            if name.contains("floor") || name.contains("standing") { return .standingLamp }
            if name.contains("bedside") || name.contains("table") { return .tableLamp }
            return .deskLamp
        }
        return .ceilingLight
    }

    public init(
        id: UUID = UUID(),
        name: String,
        layer: LightLayer,
        positionX: Double = 0.0,
        positionZ: Double = 0.0,
        elevationY: Double = 2.4,
        lumens: Double = 800.0,
        colorTemperatureKelvin: Int = 3000,
        isOn: Bool = true,
        kind: LightKind? = nil
    ) {
        self.id = id
        self.name = name
        self.layer = layer
        self.positionX = positionX
        self.positionZ = positionZ
        self.elevationY = elevationY
        self.lumens = lumens
        self.colorTemperatureKelvin = colorTemperatureKelvin
        self.isOn = isOn
        self.kind = kind
    }
}
