import SwiftUI

/// ملخص المذاكرة الفردية. يحتفظ `StudyHubView` بالنتيجة طوال الجلسة حتى لا
/// يعيد استهلاك طلب AI كل مرة يرجع فيها الطالب لهذه الشاشة.
struct StudySummaryView: View {
    let sourceText: String
    @Binding var summary: String?

    @Environment(AppSettings.self) private var settings

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                    Text(Loc.t("generating_summary"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let summary {
                ScrollView {
                    Text(summary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
                        .textSelection(.enabled)
                        .accessibilityIdentifier("studySummaryContent")
                        .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.orange)
                    Text(errorMessage ?? Loc.t("error_generic"))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button(Loc.t("retry")) {
                        Task { await generateSummary() }
                    }
                    .buttonStyle(.appPrimary)
                    .accessibilityIdentifier("studySummaryRetry")
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("summary"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if summary == nil {
                await generateSummary()
            }
        }
    }

    private func generateSummary() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIClient.shared.summarize(text: sourceText, lang: settings.languageCode)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty else { throw APIError.invalidResponse }
            summary = result
        } catch {
            errorMessage = Loc.t("error_generic")
        }
    }
}
