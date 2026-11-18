import RealityKit
import UIKit
import simd

/// One room-space daylight/shadow setup shared by the studio and Lighting preview.
@MainActor
enum StudioDaylightRig {
    static let cutawayOpacity: Float = 0.001

    static func configure(_ sun: DirectionalLight, geometry: LightingRoomGeometry) {
        #if !targetEnvironment(simulator)
        let span = Float(max(geometry.width, geometry.length, geometry.height))
        sun.shadow = DirectionalLightComponent.Shadow(
            shadowProjection: .fixed(zNear: 0.01, zFar: span * 6, orthographicScale: span * 3),
            depthBias: 1
        )
        #endif
    }

    static func update(_ sun: DirectionalLight, in root: Entity, geometry: LightingRoomGeometry,
                       orientation: RoomCompassOrientation?, daylight: DaylightState, enabled: Bool) {
        let engine = IlluminationSimulationEngine()
        sun.isEnabled = enabled && daylight.intensityLux > 0
        sun.light.intensity = Float(daylight.intensityLux)
        let rgb = engine.blackbodyRGB(kelvin: daylight.kelvin)
        sun.light.color = UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        let distance = Float(max(geometry.width, geometry.length, geometry.height)) * 3
        let direction = engine.sunlightDirection(for: daylight, orientation: orientation)
        sun.look(at: .zero, from: simd_normalize(direction) * distance, relativeTo: root)
    }

    static func roofOccluder(geometry: LightingRoomGeometry) -> ModelEntity {
        let roof = ProceduralRoomShellBuilder.buildCeiling(width: geometry.width + 0.24,
                                                         length: geometry.length + 0.24, height: geometry.height)
        roof.name = "SunlightRoofOccluder"
        roof.components.set(OpacityComponent(opacity: cutawayOpacity))
        roof.components.set(DynamicLightShadowComponent(castsShadow: true))
        roof.components.set(GroundingShadowComponent(castsShadow: false))
        return roof
    }

    static func setCutaway(_ entity: Entity, hidden: Bool) {
        // Camera cutaways affect visibility, never the geometry in the shadow pass.
        if !entity.isEnabled { entity.isEnabled = true }
        let opacity = entity.components[OpacityComponent.self]?.opacity
        if hidden {
            guard opacity != cutawayOpacity else { return }
            entity.components.set(OpacityComponent(opacity: cutawayOpacity))
        } else if opacity != nil {
            entity.components.remove(OpacityComponent.self)
        }
    }
}
