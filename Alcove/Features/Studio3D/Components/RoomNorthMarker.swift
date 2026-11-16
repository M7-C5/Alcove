import RealityKit
import UIKit
import simd

/// A floor marker in room coordinates, so orbiting the camera never changes north.
@MainActor
enum RoomNorthMarker {
    static func build(orientation: RoomCompassOrientation, width: Double, length: Double) -> Entity {
        let marker = Entity()
        marker.name = "RoomNorthMarker"
        marker.position = [Float(-width / 2 + 0.5), 0.025, Float(length / 2 - 0.5)]
        let direction = orientation.direction(forBearingDegrees: 0)
        marker.orientation = simd_quatf(from: SIMD3<Float>(0, 0, -1), to: direction)
        let material = UnlitMaterial(color: .systemBrown)
        let shaft = ModelEntity(mesh: .generateBox(size: [0.035, 0.008, 0.32]), materials: [material])
        marker.addChild(shaft)
        for sign: Float in [-1, 1] {
            let wing = ModelEntity(mesh: .generateBox(size: [0.035, 0.008, 0.17]), materials: [material])
            wing.position = [sign * 0.055, 0, -0.11]
            wing.orientation = simd_quatf(angle: sign * .pi / 4, axis: [0, 1, 0])
            marker.addChild(wing)
        }
        let label = ModelEntity(mesh: .generateText("N", extrusionDepth: 0.001,
                                                   font: .boldSystemFont(ofSize: 0.12)), materials: [material])
        label.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        label.position = [-0.045, 0, -0.23]
        marker.addChild(label)
        disableShadows(marker)
        return marker
    }

    private static func disableShadows(_ entity: Entity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        entity.components.set(GroundingShadowComponent(castsShadow: false))
        for child in entity.children { disableShadows(child) }
    }
}

/// Screen overlay remains readable even when the floor marker is behind furniture or a cutaway wall.
@MainActor
final class RoomNorthIndicator: UIView {
    private let arrow = UIImageView(image: UIImage(systemName: "arrow.up"))
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemBrown.withAlphaComponent(0.3).cgColor
        arrow.tintColor = .systemBrown
        arrow.contentMode = .scaleAspectFit
        label.text = "N"
        label.font = .preferredFont(forTextStyle: .caption1).withSize(14)
        label.textAlignment = .center
        label.textColor = .systemBrown
        addSubview(arrow)
        addSubview(label)
        isAccessibilityElement = true
        accessibilityLabel = "Magnetic north"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(in view: ARView, orientation: RoomCompassOrientation?, cameraOrientation: simd_quatf) {
        guard let orientation else { isHidden = true; return }
        isHidden = false
        frame = CGRect(x: view.safeAreaInsets.left + 20, y: view.safeAreaInsets.top + 90, width: 64, height: 76)
        let direction = cameraOrientation.inverse.act(orientation.direction(forBearingDegrees: 0))
        arrow.transform = .identity
        arrow.frame = CGRect(x: 17, y: 12, width: 30, height: 36)
        arrow.transform = CGAffineTransform(rotationAngle: CGFloat(atan2(direction.x, direction.y)))
        label.frame = CGRect(x: 0, y: 51, width: 64, height: 20)
    }
}
