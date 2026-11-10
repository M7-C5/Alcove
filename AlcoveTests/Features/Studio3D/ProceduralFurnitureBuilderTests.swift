import Foundation
import Testing
import RealityKit
@testable import Alcove

@Suite("Procedural Furniture Builder Tests") @MainActor
struct ProceduralFurnitureBuilderTests {

    @Test func buildsDetailedBedHierarchy() {
        let bed = Furniture(
            name: "Queen Bed",
            category: .bed,
            positionX: 0,
            positionY: 0,
            positionZ: 0,
            width: 1.6,
            length: 2.0,
            height: 0.85
        )

        let entity = ProceduralFurnitureBuilder.buildDetailedEntity(for: bed)
        #expect(entity.name == "DetailedModel")
        #expect(!entity.children.isEmpty)

        guard let bedEntity = entity.findEntity(named: "Bed") else {
            Issue.record("Bed entity should exist in hierarchy")
            return
        }
        #expect(bedEntity.children.count >= 5) // Headboard, platform, legs, mattress, pillows, duvet
    }

    @Test func buildsDetailedDeskHierarchy() {
        let desk = Furniture(
            name: "Home Office Desk",
            category: .table,
            positionX: 0,
            positionY: 0,
            positionZ: 0,
            width: 1.3,
            length: 0.7,
            height: 0.75
        )

        let entity = ProceduralFurnitureBuilder.buildDetailedEntity(for: desk)
        #expect(entity.name == "DetailedModel")

        guard let deskEntity = entity.findEntity(named: "Desk") else {
            Issue.record("Desk entity should exist in hierarchy")
            return
        }
        #expect(deskEntity.children.count >= 5) // Top, legs, modesty panel, mat, laptop
    }

    @Test func buildsDetailedErgonomicChairHierarchy() {
        let chair = Furniture(
            name: "Ergonomic Desk Chair",
            category: .seating,
            positionX: 0,
            positionY: 0,
            positionZ: 0,
            width: 0.6,
            length: 0.6,
            height: 0.95
        )

        let entity = ProceduralFurnitureBuilder.buildDetailedEntity(for: chair)
        guard let chairEntity = entity.findEntity(named: "Chair") else {
            Issue.record("Chair entity should exist in hierarchy")
            return
        }
        #expect(chairEntity.children.count >= 5) // Hub, spokes, column, seat, backrest, arms
    }

    @Test func buildsDetailedWardrobeHierarchy() {
        let wardrobe = Furniture(
            name: "Double Wardrobe Cupboard",
            category: .storage,
            positionX: 0,
            positionY: 0,
            positionZ: 0,
            width: 1.2,
            length: 0.6,
            height: 1.9
        )

        let entity = ProceduralFurnitureBuilder.buildDetailedEntity(for: wardrobe)
        guard let wardrobeEntity = entity.findEntity(named: "Wardrobe") else {
            Issue.record("Wardrobe entity should exist in hierarchy")
            return
        }
        #expect(wardrobeEntity.children.count >= 4) // Plinth, body, seam, handles
    }

    @Test func buildsDetailedNightstandHierarchy() {
        let nightstand = Furniture(
            name: "Bedside Nightstand",
            category: .table,
            positionX: 0,
            positionY: 0,
            positionZ: 0,
            width: 0.5,
            length: 0.45,
            height: 0.55
        )

        let entity = ProceduralFurnitureBuilder.buildDetailedEntity(for: nightstand)
        guard let nightstandEntity = entity.findEntity(named: "Nightstand") else {
            Issue.record("Nightstand entity should exist in hierarchy")
            return
        }
        #expect(nightstandEntity.children.count >= 6) // Legs, body, drawer pulls, table lamp
    }

    @Test func buildsDetailedFloorLampHierarchyWithLight() {
        let lamp = Furniture(
            name: "Corner Floor Lamp",
            category: .lighting,
            positionX: 0,
            positionY: 0,
            positionZ: 0,
            width: 0.4,
            length: 0.4,
            height: 1.6
        )

        let entity = ProceduralFurnitureBuilder.buildDetailedEntity(for: lamp)
        guard let lampEntity = entity.findEntity(named: "FloorLamp") else {
            Issue.record("FloorLamp entity should exist in hierarchy")
            return
        }
        #expect(lampEntity.children.count >= 3) // Base, pole, shade, point light

        let bulb = lampEntity.findEntity(named: "LampBulb") as? PointLight
        #expect(bulb != nil)
        #expect(bulb?.light.intensity ?? 0 > 0)
    }
}
