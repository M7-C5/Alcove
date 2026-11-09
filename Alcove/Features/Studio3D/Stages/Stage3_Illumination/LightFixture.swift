import Foundation

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

    public init(
        id: UUID = UUID(),
        name: String,
        layer: LightLayer,
        positionX: Double = 0.0,
        positionZ: Double = 0.0,
        elevationY: Double = 2.4,
        lumens: Double = 800.0,
        colorTemperatureKelvin: Int = 3000,
        isOn: Bool = true
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
    }
}
