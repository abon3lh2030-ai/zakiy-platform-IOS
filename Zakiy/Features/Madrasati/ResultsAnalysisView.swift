import SwiftUI

/// محلّل نتائج الطلاب (معلم) - يلصق نص خام (أسماء ودرجات بأي صيغة) ويطلع
/// تحليل - توليد لحظي بدون حفظ (الباك إند ما يوفّر مسار حفظ لهذه الأداة).
struct ResultsAnalysisView: View {
    @Environment(AppSettings.self) private var settings

    @State private var rawResults = ""
    @State private var content: ResultsAnalysisContent?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Loc.t("results_analysis_desc")).font(.subheadline).foregroundStyle(.secondary)

                TextEditor(text: $rawResults)
                    .frame(minHeight: 160)
                    .overlay(alignment: .topLeading) {
                        if rawResults.isEmpty {
                            Text(Loc.t("ph_raw_results"))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8).padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(6)
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 10))

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }

                Button {
                    Task { await generate() }
                } label: {
                    if isGenerating { ProgressView().frame(maxWidth: .infinity) }
                    else { Text(Loc.t("btn_generate_results_analysis")).frame(maxWidth: .infinity) }
                }
                .buttonStyle(.appPrimary)
                .disabled(isGenerating)

                if let content {
                    Divider()
                    resultSection(content)
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("results_analysis_heading"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func resultSection(_ content: ResultsAnalysisContent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledTextBlock(label: Loc.t("ra_summary_label"), text: content.overallSummary)
            LabeledBulletList(label: Loc.t("ra_strengths_label"), items: content.strengths)
            LabeledBulletList(label: Loc.t("ra_weaknesses_label"), items: content.weaknesses)
            LabeledBulletList(label: Loc.t("ra_at_risk_label"), items: content.atRiskStudents)
            LabeledBulletList(label: Loc.t("ra_recommendations_label"), items: content.recommendations)
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private func generate() async {
        errorMessage = nil
        let trimmed = rawResults.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = Loc.t("err_raw_results_required")
            return
        }
        isGenerating = true
        do {
            content = try await APIClient.shared.generateResultsAnalysis(rawResults: trimmed, lang: settings.languageCode)
        } catch {
            errorMessage = error.localizedDescription.isEmpty ? Loc.t("err_lesson_prep_gen_failed") : error.localizedDescription
        }
        isGenerating = false
    }
}
