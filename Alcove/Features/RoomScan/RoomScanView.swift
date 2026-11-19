import SwiftUI
import RoomPlan
import SwiftData

public struct RoomScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel = RoomScanViewModel()

    public var onScanComplete: ((UUID) -> Void)?
    public var onCancel: (() -> Void)?

    public init(
        onScanComplete: ((UUID) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.onScanComplete = onScanComplete
        self.onCancel = onCancel
    }

    private var isShowingErrorAlert: Binding<Bool> {
        Binding(
            get: {
                if case .error = viewModel.state { return true }
                return false
            },
            set: { newValue in
                if !newValue, case .error = viewModel.state {
                    viewModel.state = .ready
                }
            }
        )
    }

    private var errorMessage: String {
        if case .error(let message) = viewModel.state {
            return message
        }
        return ""
    }

    public var body: some View {
        Group {
            if viewModel.state == .unsupported {
                hardwareRequiredView
            } else if viewModel.state == .cameraDenied {
                cameraPermissionView
            } else {
                scannerView
            }
        }
        .task {
            await viewModel.ensureCameraPermissionIfNeeded()
        }
        .onAppear {
            if case .completed = viewModel.state {
                viewModel.reset()
            }
        }
        .onDisappear {
            viewModel.pauseScanningIfActive()
        }
        .onChange(of: viewModel.state) { _, newState in
            switch newState {
            case .completed(let roomId):
                onScanComplete?(roomId)
                dismiss()
            case .cancelled:
                onCancel?()
                dismiss()
            default:
                break
            }
        }
    }

    private var scannerView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isCameraAuthorized {
                RoomCaptureViewWrapper(
                    captureView: viewModel.captureView,
                    isCancelled: viewModel.isCancelled,
                    onReadyToScan: {
                        if viewModel.state == .ready {
                            viewModel.startScanning()
                        }
                    },
                    onComplete: { capturedRoom in
                        viewModel.process(capturedRoom: capturedRoom, modelContext: modelContext)
                    },
                    onError: { error in
                        if !viewModel.isCancelled {
                            viewModel.state = .error(error.localizedDescription)
                        }
                    }
                )
                .ignoresSafeArea()
            }

            RoomScanOverlayView(
                state: viewModel.state,
                isHidingControls: viewModel.isShowingConfirmationAlert || isShowingErrorAlert.wrappedValue,
                onDone: {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        viewModel.requestFinishScanning()
                    }
                },
                onCancel: {
                    viewModel.cancelScanning()
                }
            )

            if viewModel.isShowingConfirmationAlert {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            viewModel.dismissConfirmationAlert()
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)

                RoomScanDoneAlert(
                    onNo: {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            viewModel.dismissConfirmationAlert()
                        }
                    },
                    onYes: {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            viewModel.confirmFinishScanning()
                        }
                    }
                )
                .offset(y: -36)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(2)
            } else if isShowingErrorAlert.wrappedValue {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)

                RoomScanMascotAlert(
                    title: "Scan Incomplete",
                    message: errorMessage,
                    secondaryTitle: "Cancel",
                    onSecondary: {
                        viewModel.cancelScanning()
                    },
                    primaryTitle: "Try Again",
                    onPrimary: {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            viewModel.startScanning()
                        }
                    }
                )
                .offset(y: -36)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(2)
            }
        }
    }

    private var cameraPermissionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 54))
                .foregroundStyle(Color.alcoveInk)

            VStack(spacing: 8) {
                Text("Camera Access Required")
                    .font(.custom("Cleanow", size: 30, relativeTo: .title))
                    .foregroundStyle(Color.alcoveInk)

                Text("Alcove requires camera access to scan your room in 3D. Please enable camera access in Settings.")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.alcoveMutedInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                TactilePillButton(
                    title: "Open Settings",
                    size: .compact,
                    appearance: .primary
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }

                TactilePillButton(
                    title: "Cancel",
                    size: .compact,
                    appearance: .cream
                ) {
                    onCancel?()
                    dismiss()
                }
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.alcoveBackground.ignoresSafeArea())
    }

    private var hardwareRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.alcoveInk)

            VStack(spacing: 8) {
                Text("LiDAR Scanner Required")
                    .font(.custom("Cleanow", size: 30, relativeTo: .title))
                    .foregroundStyle(Color.alcoveInk)

                Text("Alcove requires an iPad Pro equipped with Apple's LiDAR Scanner to capture real-world room geometry.")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.alcoveMutedInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                #if DEBUG
                TactilePillButton(
                    title: "Load Sample Room",
                    size: .compact,
                    appearance: .primary,
                    systemImage: "sparkles"
                ) {
                    viewModel.loadMockRoom(modelContext: modelContext)
                }
                #endif

                TactilePillButton(
                    title: "Cancel",
                    size: .compact,
                    appearance: .cream
                ) {
                    onCancel?()
                    dismiss()
                }
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.alcoveBackground.ignoresSafeArea())
    }
}
