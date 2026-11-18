import Foundation
import SwiftData
import simd

/// Maps sanitized RoomPlan capture payloads into Alcove's dual-layout `Room` model.
public final class RoomCaptureMapper: Sendable {

    private let sanitizer: RoomCaptureSanitizer

    public init(sanitizer: RoomCaptureSanitizer? = nil) {
        self.sanitizer = sanitizer ?? RoomCaptureSanitizer()
    }

    public func mapToRoom(payload: CapturedRoomPayload, roomName: String = "Scanned Room") -> Room {
        let longerSide = Double(max(payload.roomLength, payload.roomWidth))
        let shorterSide = Double(min(payload.roomLength, payload.roomWidth))
        let roomHeight = Double(max(2.2, payload.roomHeight))

        let snapshot: RoomPlanSnapshot? = payload.walls.isEmpty
            ? nil
            : RoomPlanSnapshot(walls: payload.walls, floorLevel: payload.floorLevel)

        // RoomPlanSnapshot aligns local X along the longest wall (primaryWall) and Z perpendicular to it.
        let roomWidth = snapshot != nil ? longerSide : shorterSide
        let roomLength = snapshot != nil ? shorterSide : longerSide

        let sanitizedObjects = sanitizer.sanitize(
            objects: payload.objects,
            roomWidth: payload.roomWidth,
            roomLength: payload.roomLength,
            walls: payload.walls,
            floorLevel: payload.floorLevel
        )

        var furnitures: [Furniture] = []
        for obj in sanitizedObjects {
            let rawX: Float
            let rawY: Float
            let rawZ: Float
            let yaw: Float

            if let snapshot {
                let local = snapshot.localCoordinates(worldX: obj.position.x, worldZ: obj.position.z)
                rawX = local.x
                rawZ = local.y
                yaw = snapshot.localYaw(obj.rotationYaw)
                rawY = max(0.0, obj.position.y - payload.floorLevel)
            } else {
                rawX = obj.position.x
                rawY = max(0.0, obj.position.y - payload.floorLevel)
                rawZ = obj.position.z
                yaw = obj.rotationYaw
            }

            let objWidth = Double(max(0.25, obj.dimensions.x))
            let objLength = Double(max(0.25, obj.dimensions.z))
            let clamped = FurnitureTransformEngine.clampPosition(
                position: SIMD3<Float>(rawX, rawY, rawZ),
                furnitureWidth: Float(objWidth),
                furnitureLength: Float(objLength),
                rotationYaw: yaw,
                roomWidth: Float(roomWidth),
                roomLength: Float(roomLength)
            )

            let mapped = Self.mapCategoryAndName(
                sanitizedCategory: obj.category,
                width: Double(obj.dimensions.x),
                length: Double(obj.dimensions.z)
            )

            let furniture = Furniture(
                name: mapped.name,
                category: mapped.category,
                positionX: Double(clamped.x),
                positionY: Double(clamped.y),
                positionZ: Double(clamped.z),
                rotationYaw: Double(yaw),
                width: objWidth,
                length: objLength,
                height: Double(max(0.25, obj.dimensions.y)),
                isArchived: false,
                isUserAdded: false
            )
            furnitures.append(furniture)
        }

        let baseline = Layout(
            name: "Original Scan",
            isBaseline: true,
            furnitures: furnitures
        )
        let working = baseline.createCopy(name: "Working Layout", isBaseline: false)

        let room = Room(
            name: roomName,
            dimensionsWidth: roomWidth,
            dimensionsLength: roomLength,
            dimensionsHeight: roomHeight,
            baselineLayout: baseline,
            workingLayout: working
        )
        baseline.room = room
        working.room = room

        return room
    }

    private static func mapCategoryAndName(
        sanitizedCategory: String,
        width: Double,
        length: Double
    ) -> (category: FurnitureCategory, name: String) {
        switch sanitizedCategory.lowercased() {
        case "bed":
            return (.bed, "Bed")
        case "desk":
            return (.table, "Work Desk")
        case "table":
            if max(width, length) <= 0.65 {
                return (.table, "Nightstand")
            }
            return (.table, "Table")
        case "chair":
            return (.seating, "Chair")
        case "sofa":
            return (.seating, "Sofa")
        case "closet", "storage":
            return (.storage, "Wardrobe")
        case "lamp", "lighting":
            return (.lighting, "Floor Lamp")
        case "television":
            return (.decor, "TV Console")
        case "fireplace":
            return (.decor, "Fireplace")
        default:
            return (.other, "Furniture")
        }
    }
}
