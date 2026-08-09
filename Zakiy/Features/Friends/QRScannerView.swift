import AVFoundation
import SwiftUI

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannedUserId: String?
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var requestSent = false

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerRepresentable { code in
                    handleScan(code)
                }
                .ignoresSafeArea()

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

    private func handleScan(_ code: String) {
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

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

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
