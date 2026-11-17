import Foundation
import SwiftData

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

        let sanitizedObjects = sanitizer.sanitize(
            objects: payload.objects,
            roomWidth: payload.roomWidth,
            roomLength: payload.roomLength,
            walls: payload.walls,
            floorLevel: payload.floorLevel
        )

        var furnitures: [Furniture] = []
        for obj in sanitizedObjects {
            let posX: Float
            let posY: Float
            let posZ: Float
            let yaw: Float

            if let snapshot {
                let local = snapshot.localCoordinates(worldX: obj.position.x, worldZ: obj.position.z)
                posX = local.x
                posZ = local.y
                yaw = snapshot.localYaw(obj.rotationYaw)
                posY = max(0.0, obj.position.y - payload.floorLevel)
            } else {
                posX = obj.position.x
                posY = max(0.0, obj.position.y - payload.floorLevel)
                posZ = obj.position.z
                yaw = obj.rotationYaw
            }

            let mapped = Self.mapCategoryAndName(
                sanitizedCategory: obj.category,
                width: Double(obj.dimensions.x),
                length: Double(obj.dimensions.z)
            )

            let furniture = Furniture(
                name: mapped.name,
                category: mapped.category,
                positionX: Double(posX),
                positionY: Double(posY),
                positionZ: Double(posZ),
                rotationYaw: Double(yaw),
                width: Double(max(0.25, obj.dimensions.x)),
                length: Double(max(0.25, obj.dimensions.z)),
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
            dimensionsWidth: shorterSide,
            dimensionsLength: longerSide,
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
