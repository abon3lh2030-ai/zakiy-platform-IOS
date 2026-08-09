import SwiftUI

struct MyQRCodeView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    private var qrImage: UIImage? {
        guard let userId = auth.userId else { return nil }
        return QRCodeGenerator.image(for: "zakiy://profile/\(userId)")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .padding(20)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                } else {
                    ProgressView()
                }
                Text(auth.username)
                    .font(.title3.bold())
                Text(Loc.t("qr_scan_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .background(Color.appBackground)
            .navigationTitle(Loc.t("my_qr_code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("close")) { dismiss() }
                }
            }
        }
    }
}
