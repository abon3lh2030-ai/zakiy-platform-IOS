import SwiftUI
import UIKit

/// مولّد نشاط إثرائي (معلم) - توليد لحظي بدون حفظ (الباك إند ما يوفّر مسار
/// حفظ لهذه الأداة إطلاقًا).
struct EnrichmentView: View {
    @Environment(AppSettings.self) private var settings

    @State private var subject = ""
    @State private var gradeLevel = ""
    @State private var topic = ""
    @State private var content: EnrichmentContent?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var copyButtonLabel = Loc.t("btn_copy_lesson_prep")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Loc.t("enrichment_desc")).font(.subheadline).foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    TextField(Loc.t("ph_lesson_prep_subject"), text: $subject)
                        .textFieldStyle(.roundedBorder)
                    TextField(Loc.t("ph_lesson_prep_grade"), text: $gradeLevel)
                        .textFieldStyle(.roundedBorder)
                    TextField(Loc.t("ph_topic"), text: $topic)
                        .textFieldStyle(.roundedBorder)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }

                Button {
                    Task { await generate() }
                } label: {
                    if isGenerating { ProgressView().frame(maxWidth: .infinity) }
                    else { Text(Loc.t("btn_generate_enrichment")).frame(maxWidth: .infinity) }
                }
                .buttonStyle(.appPrimary)
                .disabled(isGenerating)

                if let content {
                    Divider()
                    resultSection(content)
                    Button(copyButtonLabel) { copyToClipboard(content) }
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("enrichment_heading"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func resultSection(_ content: EnrichmentContent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(content.title).font(.title3.weight(.bold))
            Text(content.description).font(.subheadline)
            LabeledBulletList(label: Loc.t("lp_steps_label"), items: content.instructions)
            if let materials = content.materialsNeeded, !materials.isEmpty {
                Text("\(Loc.t("lp_enrichment_label")): \(materials)").font(.subheadline)
            }
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private func generate() async {
        errorMessage = nil
        let trimmedSubject = subject.trimmingCharacters(in: .whitespaces)
        let trimmedGrade = gradeLevel.trimmingCharacters(in: .whitespaces)
        let trimmedTopic = topic.trimmingCharacters(in: .whitespaces)
        guard !trimmedSubject.isEmpty, !trimmedGrade.isEmpty, !trimmedTopic.isEmpty else {
            errorMessage = Loc.t("err_lesson_prep_fields_required")
            return
        }
        isGenerating = true
        do {
            content = try await APIClient.shared.generateEnrichment(subject: trimmedSubject, gradeLevel: trimmedGrade, topic: trimmedTopic, lang: settings.languageCode)
        } catch {
            errorMessage = error.localizedDescription.isEmpty ? Loc.t("err_lesson_prep_gen_failed") : error.localizedDescription
        }
        isGenerating = false
    }

    private func copyToClipboard(_ content: EnrichmentContent) {
        var lines = [content.title, content.description] + content.instructions.map { "- \($0)" }
        if let materials = content.materialsNeeded, !materials.isEmpty {
            lines.append(materials)
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copyButtonLabel = Loc.t("copied_label")
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copyButtonLabel = Loc.t("btn_copy_lesson_prep")
        }
    }
}
