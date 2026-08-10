import AVFoundation
import SwiftUI

/// Camera state as reported by `ScannerViewController` — needed because a silent black screen
/// (no permission prompt shown, no device found — e.g. on Simulator with no camera hardware, or
/// after a prior "Don't Allow") gives no feedback at all otherwise.
enum CameraAvailability: Equatable {
    case checking
    case ready
    case denied
    case noCameraHardware
}

struct QRScannerView: View {
    /// When set, the scanner accepts a bare room code (or `zakiy://room/<code>`) and hands it
    /// back instead of running the default friend-add flow — used from the room lobby's
    /// "scan QR" entry point.
    var onRoomCode: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var scannedUserId: String?
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var requestSent = false
    @State private var cameraAvailability: CameraAvailability = .checking
    @State private var manualCode = ""

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraAvailability == .ready {
                    QRScannerRepresentable(onScan: handleScan, onAvailabilityChange: { cameraAvailability = $0 })
                        .ignoresSafeArea()
                } else {
                    // Also drives the initial permission check/request — the representable only
                    // reports availability once its session actually configures.
                    QRScannerRepresentable(onScan: handleScan, onAvailabilityChange: { cameraAvailability = $0 })
                        .ignoresSafeArea()
                        .opacity(0.001) // keep it running (to receive the availability callback) without showing a stuck black frame

                    unavailableOverlay
                }

                VStack {
                    Spacer()
                    if isSending {
                        ProgressView().padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    } else if requestSent {
                        Label(Loc.t("friend_request_sent"), systemImage: "checkmark.circle.fill")
                            .padding(14)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    } else if let errorMessage {
                        Text(errorMessage)
                            .padding(14)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Spacer().frame(height: 40)
                }
            }
            .navigationTitle(Loc.t("scan_qr_code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("close")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var unavailableOverlay: some View {
        VStack(spacing: 16) {
            switch cameraAvailability {
            case .checking:
                ProgressView()
            case .denied:
                Image(systemName: "camera.fill").font(.system(size: 40)).foregroundStyle(.secondary)
                Text(Loc.t("camera_permission_denied")).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button(Loc.t("open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.appPrimary)
            case .noCameraHardware, .ready:
                Image(systemName: "camera.fill").font(.system(size: 40)).foregroundStyle(.secondary)
                Text(Loc.t("camera_unavailable")).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }

            // Manual code entry is the only way to test the room-join scanner on Simulator
            // (no camera hardware), and a reasonable fallback for a broken camera generally.
            if onRoomCode != nil {
                VStack(spacing: 10) {
                    TextField(Loc.t("room_code_placeholder"), text: $manualCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                    Button(Loc.t("join")) {
                        onRoomCode?(manualCode.trimmingCharacters(in: .whitespaces).uppercased())
                    }
                    .buttonStyle(.bordered)
                    .disabled(manualCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func handleScan(_ code: String) {
        if let onRoomCode {
            guard scannedUserId == nil else { return }
            scannedUserId = code // reuse as a simple "already handled" guard
            if let range = code.range(of: "zakiy://room/") {
                onRoomCode(String(code[range.upperBound...]))
            } else {
                onRoomCode(code.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return
        }

        guard scannedUserId == nil else { return }
        guard let range = code.range(of: "zakiy://profile/") else {
            errorMessage = Loc.t("invalid_qr_code")
            return
        }
        let userId = String(code[range.upperBound...])
        scannedUserId = userId
        Task {
            isSending = true
            do {
                try await APIClient.shared.sendFriendRequest(toUserId: userId)
                requestSent = true
            } catch {
                errorMessage = Loc.t("error_generic")
            }
            isSending = false
        }
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onAvailabilityChange: (CameraAvailability) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        vc.onAvailabilityChange = onAvailabilityChange
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onAvailabilityChange: ((CameraAvailability) -> Void)?
    private let session = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestAccessThenConfigure()
    }

    private func requestAccessThenConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.onAvailabilityChange?(.denied)
                    }
                }
            }
        case .denied, .restricted:
            onAvailabilityChange?(.denied)
        @unknown default:
            onAvailabilityChange?(.denied)
        }
    }

    private func configureSession() {
        // No camera hardware at all (e.g. iOS Simulator without a mapped webcam) — report it
        // explicitly instead of leaving a permanently blank/black view with no explanation.
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onAvailabilityChange?(.noCameraHardware)
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onAvailabilityChange?(.noCameraHardware)
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        onAvailabilityChange?(.ready)

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        onScan?(value)
    }
}
