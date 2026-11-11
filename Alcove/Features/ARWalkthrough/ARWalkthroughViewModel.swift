import Foundation
import Observation
import simd
import AVFoundation

/// State of room placement within the 1:1 AR physical environment.
public enum ARPlacementState: Equatable, Sendable {
    case detectingPlanes
    case readyToPlace(position: SIMD3<Float>, rotationYaw: Float)
    case placed(position: SIMD3<Float>, rotationYaw: Float)

    public var isPlaced: Bool {
        if case .placed = self { return true }
        return false
    }
}

/// Camera permission status for AR world tracking.
public enum CameraPermissionStatus: Equatable, Sendable {
    case authorized
    case notDetermined
    case denied
}

/// `@Observable @MainActor` ViewModel managing 1:1 Life-Size AR walkthrough lifecycle,
/// floor plane anchoring, and room boundary presence.
@Observable
@MainActor
public final class ARWalkthroughViewModel {
    public let room: Room

    public var placementState: ARPlacementState = .detectingPlanes
    public var isCameraInsideRoom: Bool = false
    public var roomRotationYaw: Float = 0.0
    public var cameraPermission: CameraPermissionStatus = .authorized
    public var sessionErrorMessage: String? = nil
    public var trackingStatusMessage: String? = nil

    public init(room: Room) {
        self.room = room
    }

    public var isPlaced: Bool {
        placementState.isPlaced
    }

    public var instructionMessage: String {
        if let sessionErrorMessage {
            return sessionErrorMessage
        }
        if cameraPermission == .denied {
            return "Camera permission required"
        }
        if let trackingStatusMessage {
            return trackingStatusMessage
        }

        switch placementState {
        case .detectingPlanes:
            return "Point iPad at the floor to find a surface"
        case .readyToPlace:
            return "Tap screen to place room at 1:1 life-size scale"
        case .placed:
            return isCameraInsideRoom ? "You are inside the room" : "Walk inside to explore your redesign"
        }
    }

    /// Evaluates camera permission status for AR capture.
    public func checkCameraPermission() {
        #if targetEnvironment(simulator)
        cameraPermission = .authorized
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermission = .authorized
        case .notDetermined:
            cameraPermission = .notDetermined
        case .denied, .restricted:
            cameraPermission = .denied
        @unknown default:
            cameraPermission = .denied
        }
        #endif
    }

    /// Explicitly requests camera permission when not determined.
    public func requestCameraPermission() async {
        #if !targetEnvironment(simulator)
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermission = granted ? .authorized : .denied
        #endif
    }

    /// Updates reticle candidate floor hit when searching for placement.
    public func updateCandidateHit(position: SIMD3<Float>) {
        guard !isPlaced else { return }
        placementState = .readyToPlace(position: position, rotationYaw: roomRotationYaw)
    }

    /// Anchors the room at the current candidate or specified position.
    public func anchorRoom(at position: SIMD3<Float>? = nil) {
        let finalPos: SIMD3<Float>
        if let position {
            finalPos = position
        } else if case .readyToPlace(let pos, _) = placementState {
            finalPos = pos
        } else {
            return
        }

        placementState = .placed(position: finalPos, rotationYaw: roomRotationYaw)
    }

    /// Rotates the room around the Y-axis.
    public func rotateRoom(by deltaAngle: Float) {
        roomRotationYaw = ARPlacementEngine.normalizeAngle(roomRotationYaw + deltaAngle)
        if case .placed(let pos, _) = placementState {
            placementState = .placed(position: pos, rotationYaw: roomRotationYaw)
        } else if case .readyToPlace(let pos, _) = placementState {
            placementState = .readyToPlace(position: pos, rotationYaw: roomRotationYaw)
        }
    }

    /// Resets placement to allow relocating the room in the physical space.
    public func repositionRoom() {
        placementState = .detectingPlanes
        isCameraInsideRoom = false
    }

    /// Updates presence check based on user's real camera position relative to room bounds.
    public func updateCameraPresence(localCameraPosition: SIMD3<Float>) {
        let roomW = Float(room.dimensionsWidth)
        let roomL = Float(room.dimensionsLength)
        let roomH = Float(room.dimensionsHeight)

        isCameraInsideRoom = CeilingCutawayEvaluator.isCameraInsideRoom(
            localCameraPosition: localCameraPosition,
            roomWidth: roomW,
            roomLength: roomL,
            roomHeight: roomH
        )
    }
}
