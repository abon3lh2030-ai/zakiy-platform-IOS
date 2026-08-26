import SwiftUI

/// شيت تصدير كشف الدرجات - يعرض رابط تنزيل موقّع (صالح ساعة وحدة) كـQR
/// (بنفس مكوّن QRCodeGenerator المستخدم بميزة "أصدقائي") + الرابط نفسه قابل
/// للفتح المباشر أو المشاركة (ShareSheet الموجودة أصلًا بالتطبيق).
struct GradesheetExportSheet: View {
    let urlString: String

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    private var qrImage: UIImage? { QRCodeGenerator.image(for: urlString) }
    private var url: URL? { URL(string: urlString) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(20)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                } else {
                    ProgressView()
                }

                Text(Loc.t("gradesheet_export_qr_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                HStack(spacing: 12) {
                    Button {
                        if let url { UIApplication.shared.open(url) }
                    } label: {
                        Label(Loc.t("btn_open_link"), systemImage: "safari")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showShareSheet = true
                    } label: {
                        Label(Loc.t("btn_share_link"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle(Loc.t("gradesheet_export_heading"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("close")) { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [urlString])
            }
        }
    }
}
