import Foundation
import SwiftData
import Testing
import simd
@testable import Alcove

@Suite("RoomScan & Capture Mapper Tests") @MainActor
struct RoomScanTests {

    @Test func mapperProducesDualLayoutRoomWithMatchedFurniture() {
        let walls = [
            ScannedWallPayload(position: [0, 1.3, -2.0], dimensions: [4.5, 2.6, 0.1], rotationYaw: 0),
            ScannedWallPayload(position: [0, 1.3, 2.0], dimensions: [4.5, 2.6, 0.1], rotationYaw: .pi),
            ScannedWallPayload(position: [2.25, 1.3, 0], dimensions: [4.0, 2.6, 0.1], rotationYaw: .pi / 2),
            ScannedWallPayload(position: [-2.25, 1.3, 0], dimensions: [4.0, 2.6, 0.1], rotationYaw: -.pi / 2)
        ]
        let objects = [
            ScannedObjectPayload(rawCategory: "bed", position: [-1.0, 0.4, -0.8], dimensions: [1.6, 0.85, 2.0], rotationYaw: 0),
            ScannedObjectPayload(rawCategory: "table", position: [1.2, 0.38, -1.2], dimensions: [1.3, 0.75, 0.7], rotationYaw: 0),
            ScannedObjectPayload(rawCategory: "chair", position: [1.1, 0.45, -0.7], dimensions: [0.55, 0.85, 0.55], rotationYaw: 0.2),
            ScannedObjectPayload(rawCategory: "chair", position: [1.4, 0.45, -0.7], dimensions: [0.55, 0.85, 0.55], rotationYaw: -0.2)
        ]
        let payload = CapturedRoomPayload(
            roomLength: 4.0,
            roomWidth: 4.5,
            roomHeight: 2.6,
            floorLevel: 0.0,
            walls: walls,
            openings: [
                ScannedOpeningPayload(type: "window", position: [0.0, 1.4, -2.0], dimensions: [1.4, 1.1, 0.1], rotationYaw: 0)
            ],
            objects: objects
        )

        let room = RoomCaptureMapper().mapToRoom(payload: payload, roomName: "Scanned Bedroom")
        #expect(room.name == "Scanned Bedroom")
        #expect(room.baselineLayout?.isBaseline == true)
        #expect(room.workingLayout?.isBaseline == false)
        // 1:1 preservation: nearby chairs and tables are not merged or moved
        #expect(room.baselineLayout?.furnitures.count == 4)
        #expect(room.workingLayout?.furnitures.count == 4)
        #expect(room.workingLayout?.furnitures.contains(where: { $0.category == .bed }) == true)
        #expect(room.workingLayout?.furnitures.contains(where: { $0.category == .table }) == true)
        #expect(room.workingLayout?.furnitures.filter { $0.category == .seating }.count == 2)
        #expect(room.planSnapshot?.wallSegments.count == 4)
        #expect(room.planSnapshot?.openings.count == 1)

        let shell = ProceduralRoomShellBuilder.buildShell(for: room)
        #expect(shell.findEntity(named: "BackWallGroup") != nil)
    }

    @Test func viewModelValidatesCornerWallsAndProcessesPayload() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let vm = RoomScanViewModel()

        // Invalid: only 1 wall
        let singleWallPayload = CapturedRoomPayload(
            roomLength: 4.0,
            roomWidth: 4.0,
            roomHeight: 2.6,
            walls: [ScannedWallPayload(position: [0, 1.3, -2.0], dimensions: [4.0, 2.6, 0.1], rotationYaw: 0)],
            openings: [],
            objects: []
        )
        #expect(vm.isValidScan(payload: singleWallPayload) == false)
        let failedRoom = vm.processPayload(singleWallPayload, modelContext: container.mainContext)
        #expect(failedRoom == nil)
        if case .error = vm.state {
            // Expected
        } else {
            Issue.record("Expected .error state for single-wall scan")
        }

        // Valid: 2+ corner walls
        let validPayload = CapturedRoomPayload(
            roomLength: 4.0,
            roomWidth: 4.0,
            roomHeight: 2.6,
            walls: [
                ScannedWallPayload(position: [0, 1.3, -2.0], dimensions: [4.0, 2.6, 0.1], rotationYaw: 0),
                ScannedWallPayload(position: [2.0, 1.3, 0], dimensions: [4.0, 2.6, 0.1], rotationYaw: .pi / 2)
            ],
            openings: [],
            objects: [
                ScannedObjectPayload(rawCategory: "sofa", position: [0.0, 0.4, 0.0], dimensions: [2.0, 0.8, 0.9], rotationYaw: 0)
            ]
        )
        #expect(vm.isValidScan(payload: validPayload) == true)
        let saved = vm.processPayload(validPayload, modelContext: container.mainContext, roomName: "Test Scan")
        #expect(saved != nil)
        #expect(vm.state == .completed(roomId: saved!.id))
    }

    @Test func confirmationAlertAndCancelStateTransitions() {
        let vm = RoomScanViewModel()
        vm.state = .scanning
        vm.requestFinishScanning()
        #expect(vm.isShowingConfirmationAlert == true)

        vm.dismissConfirmationAlert()
        #expect(vm.isShowingConfirmationAlert == false)
        #expect(vm.state == .scanning)

        vm.requestFinishScanning()
        vm.confirmFinishScanning()
        #expect(vm.isShowingConfirmationAlert == false)
        #expect(vm.state == .processing)

        vm.cancelScanning()
        #expect(vm.isCancelled == true)
        #expect(vm.state == .cancelled)
    }

    @Test func mapperAlignsLongestWallWithWidthAndPreservesExactPosition() {
        let walls = [
            ScannedWallPayload(position: [0, 1.3, -1.75], dimensions: [5.5, 2.6, 0.1], rotationYaw: 0),
            ScannedWallPayload(position: [0, 1.3, 1.75], dimensions: [5.5, 2.6, 0.1], rotationYaw: .pi),
            ScannedWallPayload(position: [2.75, 1.3, 0], dimensions: [3.5, 2.6, 0.1], rotationYaw: .pi / 2),
            ScannedWallPayload(position: [-2.75, 1.3, 0], dimensions: [3.5, 2.6, 0.1], rotationYaw: -.pi / 2)
        ]
        let objects = [
            ScannedObjectPayload(rawCategory: "sofa", position: [2.5, 0.4, 1.5], dimensions: [2.0, 0.8, 0.9], rotationYaw: 0)
        ]
        let payload = CapturedRoomPayload(
            roomLength: 3.5,
            roomWidth: 5.5,
            roomHeight: 2.6,
            floorLevel: 0.0,
            walls: walls,
            openings: [],
            objects: objects
        )

        let room = RoomCaptureMapper().mapToRoom(payload: payload, roomName: "Exact Scan")
        #expect(abs(room.dimensionsWidth - 5.5) < 0.01)
        #expect(abs(room.dimensionsLength - 3.5) < 0.01)

        let sofa = room.workingLayout?.furnitures.first
        #expect(sofa != nil)
        if let sofa {
            #expect(abs(sofa.positionX - 2.5) < 0.01)
            #expect(abs(sofa.positionZ - 1.5) < 0.01)
        }
    }
}
