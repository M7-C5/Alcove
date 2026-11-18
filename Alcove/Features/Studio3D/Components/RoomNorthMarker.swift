import RealityKit
import UIKit
import simd

/// A floor decal in room coordinates. Camera movement never changes its north bearing.
@MainActor
enum RoomNorthMarker {
    static func build(snapshot: LightingRoomSnapshot) -> Entity {
        let marker = Entity()
        marker.name = "RoomNorthMarker"
        let halfW = Float(snapshot.geometry.width / 2)
        let halfL = Float(snapshot.geometry.length / 2)
        let inset: Float = min(0.6, min(halfW, halfL) * 0.6)
        let corners: [SIMD2<Float>] = [[-halfW + inset, -halfL + inset],
                                      [-halfW + inset, halfL - inset],
                                      [halfW - inset, -halfL + inset], [halfW - inset, halfL - inset]]
        func occupied(_ point: SIMD2<Float>) -> Int {
            snapshot.furnishings.filter { item in
                let delta = point - SIMD2<Float>(item.position.x, item.position.z)
                let x = delta.x * cos(item.yaw) - delta.y * sin(item.yaw)
                let z = delta.x * sin(item.yaw) + delta.y * cos(item.yaw)
                return abs(x) < item.dimensions.x / 2 + 0.3 && abs(z) < item.dimensions.z / 2 + 0.3
            }.count
        }
        let position = corners.min { occupied($0) < occupied($1) } ?? .zero
        marker.position = [position.x, 0.018, position.y]
        let bearing = snapshot.compassOrientation?.magneticForwardBearingDegrees ?? 180
        marker.orientation = simd_quatf(angle: Float(bearing * .pi / 180), axis: [0, 1, 0])

        let ink = UnlitMaterial(color: UIColor(named: "AlcoveInk") ?? .brown)
        var halo = UnlitMaterial(color: UIColor(named: "AlcoveSurfaceElevated") ?? .white)
        halo.blending = .transparent(opacity: .init(floatLiteral: 0.55))
        let disc = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: 0.3), materials: [halo])
        marker.addChild(disc)
        let stem = ModelEntity(mesh: .generateBox(size: [0.028, 0.004, 0.28]), materials: [ink])
        stem.position = [0, 0.004, 0.015]
        marker.addChild(stem)
        for sign: Float in [-1, 1] {
            let wing = ModelEntity(mesh: .generateBox(size: [0.028, 0.004, 0.14]), materials: [ink])
            wing.position = [sign * 0.045, 0.004, -0.085]
            wing.orientation = simd_quatf(angle: sign * .pi / 4, axis: [0, 1, 0])
            marker.addChild(wing)
        }
        let sample = snapshot.compassOrientation == nil
        let text = ModelEntity(mesh: .generateText(sample ? "N?" : "N", extrusionDepth: 0.001,
                                                  font: .boldSystemFont(ofSize: 0.095)), materials: [ink])
        text.name = sample ? "NorthSampleLabel" : "NorthLabel"
        text.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        text.position = [sample ? -0.065 : -0.035, 0.006, -0.175]
        marker.addChild(text)
        disableShadows(marker)
        return marker
    }

    private static func disableShadows(_ entity: Entity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        entity.components.set(GroundingShadowComponent(castsShadow: false))
        for child in entity.children { disableShadows(child) }
    }
}
