import SwiftUI

/// تلخيص جلسة الاستكشاف بالذكاء الاصطناعي - مطابق لزر slSummaryBtn بالموقع:
/// يرسل سجل الأحداث كامل (SL.sessionLog) لنقطة /api/science-lab/summary
/// ويعرض تلخيصًا نصيًا مقروءًا.
struct ScienceLabSummarySheet: View {
    let session: ScienceLabSession

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var summary: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isLoading {
                        ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, alignment: .center).padding(.top, 40)
                    } else if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else if let summary {
                        Text(summary).font(.body)
                    } else {
                        Text(Loc.t("sl_summary_empty")).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.appBackground)
            .navigationTitle(Loc.t("sl_summary_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Loc.t("close")) { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard !session.log.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            summary = try await APIClient.shared.scienceLabSummary(log: session.log, lang: settings.languageCode)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
