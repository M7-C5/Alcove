import Foundation
import Testing
@testable import Alcove

@Suite("Furniture Catalog Add, Remove & Swap Tests") @MainActor
struct FurnitureCatalogTests {

    @Test func catalogPresetsHaveValidDimensionsAndUniqueIDs() {
        let presets = FurnitureCatalog.presets
        #expect(!presets.isEmpty)

        let uniqueIDs = Set(presets.map(\.id))
        #expect(uniqueIDs.count == presets.count)

        for item in presets {
            #expect(!item.name.isEmpty)
            #expect(item.width > 0)
            #expect(item.length > 0)
            #expect(item.height > 0)
        }
    }

    @Test func addFurnitureInsertsUserAddedItemAndPreservesBaseline() {
        let room = SampleData.createStarterRoom()
        let baselineCount = room.baselineLayout?.furnitures.count ?? 0
        let workingCountBefore = room.workingLayout?.furnitures.count ?? 0
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        let lamp = FurnitureCatalog.presets.first { $0.id == "floor_lamp" }!
        let added = vm.addFurniture(from: lamp)

        #expect(added != nil)
        #expect(added?.isUserAdded == true)
        #expect(added?.isArchived == false)
        #expect(vm.selectedFurnitureID == added?.id)
        #expect((room.workingLayout?.furnitures.count ?? 0) == workingCountBefore + 1)
        #expect((room.baselineLayout?.furnitures.count ?? 0) == baselineCount)
    }

    @Test func removeFurnitureOnlyDeletesUserAddedItems() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        // Baseline / scanned item cannot be removed
        let scannedBed = room.workingLayout?.furnitures.first { !$0.isUserAdded }
        #expect(scannedBed != nil)
        let countBeforeAttempt = room.workingLayout?.furnitures.count ?? 0
        if let scannedBed {
            vm.removeFurniture(scannedBed)
        }
        #expect((room.workingLayout?.furnitures.count ?? 0) == countBeforeAttempt)

        // User-added item can be removed
        let lamp = FurnitureCatalog.presets.first { $0.id == "floor_lamp" }!
        let added = vm.addFurniture(from: lamp)!
        #expect(vm.selectedFurnitureID == added.id)

        vm.removeFurniture(added)
        #expect(vm.selectedFurnitureID == nil)
        #expect(room.workingLayout?.furnitures.contains(where: { $0.id == added.id }) == false)
    }

    @Test func swapFurnitureUpdatesPropertiesInPlaceAndClampsInsideRoom() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        let nightstand = room.workingLayout?.furnitures.first { $0.category == .table }!
        let targetID = nightstand!.id
        let originalYaw = nightstand!.rotationYaw
        let revisionBefore = vm.dragRevision

        let kingBed = FurnitureCatalog.presets.first { $0.id == "king_bed" }!
        vm.swapFurniture(nightstand!, with: kingBed)

        let updated = room.workingLayout?.furnitures.first { $0.id == targetID }
        #expect(updated != nil)
        #expect(updated?.name == kingBed.name)
        #expect(updated?.category == kingBed.category)
        #expect(updated?.width == kingBed.width)
        #expect(updated?.length == kingBed.length)
        #expect(updated?.height == kingBed.height)
        #expect(updated?.assetIdentifier == kingBed.assetIdentifier)
        #expect(updated?.rotationYaw == originalYaw)
        #expect(vm.dragRevision > revisionBefore)
        #expect(vm.selectedFurnitureID == targetID)
    }
}
