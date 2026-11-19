import SwiftUI
import RoomPlan

@objc(AlcoveRoomCaptureCoordinator)
public final class RoomCaptureCoordinator: NSObject, RoomCaptureViewDelegate {
    var isCancelled: Bool = false
    var onComplete: ((CapturedRoom) -> Void)?
    var onError: ((Error) -> Void)?

    public override init() {
        super.init()
    }

    public required init?(coder: NSCoder) {
        super.init()
    }

    public func encode(with coder: NSCoder) {}

    public func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: (any Error)?) -> Bool {
        if isCancelled {
            return false
        }
        if let error {
            onError?(error)
            return false
        }
        return true
    }

    public func captureView(didPresent processedResult: CapturedRoom, error: (any Error)?) {
        guard !isCancelled else { return }
        if let error {
            onError?(error)
        } else {
            onComplete?(processedResult)
        }
    }
}

/// Container UIView that embeds `RoomCaptureView` and fires `onReadyToScan`
/// once attached to a `UIWindow` with non-zero bounds (avoiding cold-mount stalls).
public final class RoomCaptureContainerView: UIView {
    public let captureView: RoomCaptureView
    public var onReadyToScan: (() -> Void)?

    public init(captureView: RoomCaptureView) {
        self.captureView = captureView
        super.init(frame: .zero)
        backgroundColor = .black
        captureView.frame = bounds
        captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(captureView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        notifyReadyIfNeeded()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if captureView.frame != bounds {
            captureView.frame = bounds
        }
        notifyReadyIfNeeded()
    }

    public func notifyReadyIfNeeded() {
        guard window != nil, bounds.width > 1, bounds.height > 1 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil, self.bounds.width > 1, self.bounds.height > 1 else { return }
            self.onReadyToScan?()
        }
    }
}

public struct RoomCaptureViewWrapper: UIViewRepresentable {
    public let captureView: RoomCaptureView
    public let isCancelled: Bool
    public let onReadyToScan: (() -> Void)?
    public let onComplete: (CapturedRoom) -> Void
    public let onError: (Error) -> Void

    public init(
        captureView: RoomCaptureView,
        isCancelled: Bool = false,
        onReadyToScan: (() -> Void)? = nil,
        onComplete: @escaping (CapturedRoom) -> Void,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.captureView = captureView
        self.isCancelled = isCancelled
        self.onReadyToScan = onReadyToScan
        self.onComplete = onComplete
        self.onError = onError
    }

    public func makeUIView(context: Context) -> RoomCaptureContainerView {
        captureView.delegate = context.coordinator
        context.coordinator.isCancelled = isCancelled
        context.coordinator.onComplete = onComplete
        context.coordinator.onError = onError
        let container = RoomCaptureContainerView(captureView: captureView)
        container.onReadyToScan = onReadyToScan
        return container
    }

    public func updateUIView(_ uiView: RoomCaptureContainerView, context: Context) {
        context.coordinator.isCancelled = isCancelled
        context.coordinator.onComplete = onComplete
        context.coordinator.onError = onError
        uiView.onReadyToScan = onReadyToScan
        uiView.notifyReadyIfNeeded()
    }

    public func makeCoordinator() -> RoomCaptureCoordinator {
        RoomCaptureCoordinator()
    }
}
