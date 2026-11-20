import Foundation
import AVFoundation
import ARKit
import CoreGraphics
import Observation
import RoomPlan
import SwiftData
import simd

@Observable
@MainActor
public final class RoomScanViewModel {

    public enum ScanState: Equatable {
        case checkingHardware
        case unsupported
        case cameraDenied
        case ready
        case scanning
        case processing
        case cancelled
        case completed(roomId: UUID)
        case error(String)
    }

    public var state: ScanState = .checkingHardware
    public var isShowingConfirmationAlert: Bool = false
    public var isCancelled: Bool = false

    public var isSupported: Bool {
        RoomCaptureSession.isSupported
    }

    public private(set) var isCameraAuthorized: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        #endif
    }()

    public func ensureCameraPermissionIfNeeded() async {
        #if !targetEnvironment(simulator)
        guard isSupported else { return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isCameraAuthorized = true
            if state == .cameraDenied { state = .ready }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard !isCancelled else { return }
            isCameraAuthorized = granted
            state = granted ? .ready : .cameraDenied
        case .denied, .restricted:
            isCameraAuthorized = false
            state = .cameraDenied
        @unknown default:
            isCameraAuthorized = false
            state = .cameraDenied
        }
        #endif
    }

    @ObservationIgnored private var _captureView: RoomCaptureView?

    public var captureView: RoomCaptureView {
        if let existing = _captureView {
            return existing
        }
        let view = RoomCaptureView(frame: .zero)
        _captureView = view
        return view
    }

    private let mapper: RoomCaptureMapper
    private let compassCapture = RoomCompassCapture()

    public init(mapper: RoomCaptureMapper? = nil) {
        self.mapper = mapper ?? RoomCaptureMapper()
        checkHardware()
    }

    public func checkHardware() {
        state = isSupported ? .ready : .unsupported
    }

    public func reset() {
        isCancelled = false
        isShowingConfirmationAlert = false
        checkHardware()
    }

    public func startScanning() {
        guard isSupported else {
            state = .unsupported
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            runCaptureSession()
        case .notDetermined:
            Task { @MainActor [weak self] in
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                guard let self, !self.isCancelled else { return }
                if granted {
                    self.runCaptureSession()
                } else {
                    self.state = .cameraDenied
                }
            }
        case .denied, .restricted:
            state = .cameraDenied
        @unknown default:
            state = .cameraDenied
        }
    }

    private func runCaptureSession() {
        isCancelled = false
        isShowingConfirmationAlert = false
        compassCapture.reset()
        let configuration = RoomCaptureSession.Configuration()
        captureView.captureSession.run(configuration: configuration)
        compassCapture.start { [weak self] timestamp in
            guard let frame = self?._captureView?.captureSession.arSession.currentFrame,
                  case .normal = frame.camera.trackingState,
                  abs(frame.timestamp - timestamp) < 0.15 else { return nil }
            let z = frame.camera.transform.columns.2
            return SIMD3<Float>(-z.x, -z.y, -z.z)
        }
        state = .scanning
    }

    public func requestFinishScanning() {
        guard state == .scanning else { return }
        isShowingConfirmationAlert = true
    }

    public func dismissConfirmationAlert() {
        isShowingConfirmationAlert = false
    }

    public func confirmFinishScanning() {
        isShowingConfirmationAlert = false
        stopScanning()
    }

    public func stopScanning() {
        isCancelled = false
        compassCapture.stop()
        _captureView?.captureSession.stop()
        state = .processing
    }

    public func cancelScanning() {
        isCancelled = true
        isShowingConfirmationAlert = false
        compassCapture.stop()
        _captureView?.captureSession.stop(pauseARSession: true)
        state = .cancelled
    }

    public func pauseScanningIfActive() {
        compassCapture.stop()
        guard state == .scanning else { return }
        _captureView?.captureSession.stop(pauseARSession: true)
    }

    public func isValidScan(payload: CapturedRoomPayload) -> Bool {
        payload.walls.count >= 2 && min(payload.roomWidth, payload.roomLength) >= 1.0
    }

    public func process(
        capturedRoom: CapturedRoom,
        modelContext: ModelContext,
        roomName: String = "Scanned Room"
    ) {
        guard !isCancelled else { return }
        state = .processing

        let payload = makePayload(from: capturedRoom)
        Task { @MainActor in
            await processPayloadAndRenderThumbnail(
                payload,
                modelContext: modelContext,
                roomName: roomName
            )
        }
    }

    @discardableResult
    public func processPayload(
        _ payload: CapturedRoomPayload,
        modelContext: ModelContext,
        roomName: String = "Scanned Room"
    ) -> Room? {
        guard let room = prepareValidatedRoom(from: payload, roomName: roomName) else { return nil }
        return persistScannedRoom(room, in: modelContext)
    }

    private func processPayloadAndRenderThumbnail(
        _ payload: CapturedRoomPayload,
        modelContext: ModelContext,
        roomName: String
    ) async {
        guard let room = prepareValidatedRoom(from: payload, roomName: roomName) else { return }
        guard !isCancelled else { return }
        persistScannedRoom(room, in: modelContext)
    }

    private func prepareValidatedRoom(
        from payload: CapturedRoomPayload,
        roomName: String
    ) -> Room? {
        guard !isCancelled else { return nil }
        state = .processing

        guard isValidScan(payload: payload) else {
            state = .error("Invalid scan: A complete room requires scanning at least 2 corner walls to establish depth. Please scan around a corner before finishing.")
            return nil
        }

        let room = mapper.mapToRoom(payload: payload, roomName: roomName,
                                    compassOrientation: compassCapture.orientation)
        return room
    }

    @discardableResult
    private func persistScannedRoom(_ room: Room, in modelContext: ModelContext) -> Room? {
        modelContext.insert(room)
        do {
            try modelContext.save()
            state = .completed(roomId: room.id)
            return room
        } catch {
            state = .error("Failed to save scanned room: \(error.localizedDescription)")
            return nil
        }
    }

    #if DEBUG
    public func loadMockRoom(modelContext: ModelContext, name: String = "Scanned Room") {
        state = .processing
        let room = MockRoomGenerator.generateBedroomOfficeCombo(name: name)
        modelContext.insert(room)
        try? modelContext.save()
        state = .completed(roomId: room.id)
    }
    #endif

    // MARK: - CapturedRoom -> CapturedRoomPayload

    private func makePayload(from room: CapturedRoom) -> CapturedRoomPayload {
        var walls: [ScannedWallPayload] = []
        var wallHeights: [Float] = []
        var wallLengths: [Float] = []

        for wall in room.walls {
            let pos = SIMD3<Float>(wall.transform.columns.3.x, wall.transform.columns.3.y, wall.transform.columns.3.z)
            let yaw = atan2(-wall.transform.columns.0.z, wall.transform.columns.0.x)
            walls.append(ScannedWallPayload(
                id: wall.identifier,
                position: pos,
                dimensions: wall.dimensions,
                rotationYaw: yaw,
                transform: wall.transform
            ))
            wallHeights.append(wall.dimensions.y)
            wallLengths.append(wall.dimensions.x)
        }

        let primaryFloor = room.floors.first
        let floorCorners = primaryFloor?.polygonCorners ?? []
        let floorPolygonWorldPoints: [SIMD2<Float>] = {
            guard let floor = primaryFloor, floor.polygonCorners.count >= 3 else { return [] }
            return floor.polygonCorners.map { corner in
                let world = floor.transform * SIMD4<Float>(corner.x, corner.y, corner.z, 1.0)
                return SIMD2<Float>(world.x, world.z)
            }
        }()
        let dims = RoomDimensionExtractor.extractDimensions(
            polygonCorners: floorCorners,
            walls: walls,
            wallHeights: wallHeights,
            wallLengths: wallLengths
        )
        let floorLevel = primaryFloor?.transform.columns.3.y
            ?? (walls.map { $0.position.y - $0.dimensions.y / 2.0 }.min() ?? 0.0)

        var openings: [ScannedOpeningPayload] = []
        for window in room.windows {
            let pos = SIMD3<Float>(window.transform.columns.3.x, window.transform.columns.3.y, window.transform.columns.3.z)
            let yaw = atan2(-window.transform.columns.0.z, window.transform.columns.0.x)
            openings.append(ScannedOpeningPayload(type: "window", position: pos, dimensions: window.dimensions, rotationYaw: yaw))
        }
        for door in room.doors {
            let pos = SIMD3<Float>(door.transform.columns.3.x, door.transform.columns.3.y, door.transform.columns.3.z)
            let yaw = atan2(-door.transform.columns.0.z, door.transform.columns.0.x)
            openings.append(ScannedOpeningPayload(type: "door", position: pos, dimensions: door.dimensions, rotationYaw: yaw))
        }
        for opening in room.openings {
            let pos = SIMD3<Float>(opening.transform.columns.3.x, opening.transform.columns.3.y, opening.transform.columns.3.z)
            let yaw = atan2(-opening.transform.columns.0.z, opening.transform.columns.0.x)
            openings.append(ScannedOpeningPayload(type: "opening", position: pos, dimensions: opening.dimensions, rotationYaw: yaw))
        }

        var objects: [ScannedObjectPayload] = []
        for object in room.objects {
            let pos = SIMD3<Float>(object.transform.columns.3.x, object.transform.columns.3.y, object.transform.columns.3.z)
            let yaw = atan2(-object.transform.columns.0.z, object.transform.columns.0.x)
            let cat = stringCategory(for: object.category)
            objects.append(ScannedObjectPayload(rawCategory: cat, position: pos, dimensions: object.dimensions, rotationYaw: yaw))
        }

        return CapturedRoomPayload(
            roomLength: dims.length,
            roomWidth: dims.width,
            roomHeight: dims.height,
            floorLevel: floorLevel,
            walls: walls,
            openings: openings,
            objects: objects,
            floorPolygonWorldPoints: floorPolygonWorldPoints
        )
    }

    private func stringCategory(for category: CapturedRoom.Object.Category) -> String {
        switch category {
        case .storage: return "storage"
        case .refrigerator: return "refrigerator"
        case .stove: return "stove"
        case .bed: return "bed"
        case .sink: return "sink"
        case .washerDryer: return "washerdryer"
        case .toilet: return "toilet"
        case .bathtub: return "bathtub"
        case .oven: return "oven"
        case .dishwasher: return "dishwasher"
        case .table: return "table"
        case .sofa: return "sofa"
        case .chair: return "chair"
        case .fireplace: return "fireplace"
        case .television: return "television"
        case .stairs: return "stairs"
        @unknown default: return "unknown"
        }
    }
}
