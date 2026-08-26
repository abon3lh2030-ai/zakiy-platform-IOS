import SwiftUI
import UIKit

/// مساعد الواجب الذكي (طالب) - إنشاء/عرض/حذف. الباك إند ما يوفّر PATCH لهذه
/// الأداة، فـ"حفظ" دايمًا ينشئ جلسة جديدة (POST) - نفس ما لو ولّدت من جديد
/// فوق جلسة محفوظة بموقع الويب (`currentHomeworkHelpId = null` عند التوليد).
struct HomeworkHelpView: View {
    let existingId: String?
    var onSaved: () async -> Void = {}

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var savedId: String?
    @State private var subject = ""
    @State private var gradeLevel = ""
    @State private var topic = ""
    @State private var content: HomeworkHelpContent?

    @State private var isLoadingExisting: Bool
    @State private var isGenerating = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var generateError: String?
    @State private var saveError: String?
    @State private var showDeleteConfirm = false
    @State private var saveButtonLabel = Loc.t("btn_save_homework_help")
    @State private var copyButtonLabel = Loc.t("btn_copy_lesson_prep")

    init(existingId: String?, onSaved: @escaping () async -> Void = {}) {
        self.existingId = existingId
        self.onSaved = onSaved
        _savedId = State(initialValue: existingId)
        _isLoadingExisting = State(initialValue: existingId != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoadingExisting {
                    ProgressView(Loc.t("loading")).frame(maxWidth: .infinity)
                } else {
                    formSection

                    if let generateError {
                        Text(generateError).foregroundStyle(.red).font(.footnote)
                    }

                    Button {
                        Task { await generate() }
                    } label: {
                        if isGenerating { ProgressView().frame(maxWidth: .infinity) }
                        else { Text(Loc.t("btn_generate_homework_help")).frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.appPrimary)
                    .disabled(isGenerating)

                    if let content {
                        Divider()
                        resultSection(content)

                        if let saveError {
                            Text(saveError).foregroundStyle(.red).font(.footnote)
                        }

                        actionsRow
                    }
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(existingId != nil ? Loc.t("homework_help_view_heading") : Loc.t("homework_help_create_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .task { if let existingId { await loadExisting(existingId) } }
        .confirmationDialog(Loc.t("confirm_delete_homework_help"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(Loc.t("delete"), role: .destructive) { Task { await delete() } }
            Button(Loc.t("cancel"), role: .cancel) {}
        }
    }

    private var formSection: some View {
        VStack(spacing: 10) {
            TextField(Loc.t("ph_lesson_prep_subject"), text: $subject)
                .textFieldStyle(.roundedBorder)
            TextField(Loc.t("ph_lesson_prep_grade"), text: $gradeLevel)
                .textFieldStyle(.roundedBorder)
            TextField(Loc.t("ph_homework_topic"), text: $topic, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }

    @ViewBuilder
    private func resultSection(_ content: HomeworkHelpContent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledTextBlock(label: Loc.t("hh_explanation_label"), text: content.explanation)
            LabeledTextBlock(label: Loc.t("hh_example_label"), text: content.workedExample)

            if !content.practiceQuestions.isEmpty {
                Text(Loc.t("hh_practice_label")).font(.subheadline.weight(.semibold))
                VStack(spacing: 8) {
                    ForEach(Array(content.practiceQuestions.enumerated()), id: \.offset) { index, q in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(index + 1). \(q.question)").font(.subheadline.weight(.medium))
                            Text(q.answer).font(.subheadline)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            LabeledTextBlock(label: Loc.t("hh_tips_label"), text: content.tips)
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private var actionsRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(copyButtonLabel) { copyToClipboard() }
                    .buttonStyle(.bordered)
                Button(Loc.t("btn_regenerate_lesson_prep")) { Task { await generate() } }
                    .buttonStyle(.bordered)
                    .disabled(isGenerating)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView().frame(maxWidth: .infinity) }
                    else { Text(saveButtonLabel).frame(maxWidth: .infinity) }
                }
                .buttonStyle(.appPrimary)
                .disabled(isSaving)

                if savedId != nil {
                    Button(Loc.t("btn_delete_lesson_prep"), role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDeleting)
                }
            }
        }
    }

    private func loadExisting(_ id: String) async {
        isLoadingExisting = true
        do {
            let detail = try await APIClient.shared.homeworkHelpDetail(id: id)
            subject = detail.subject
            gradeLevel = detail.gradeLevel
            topic = detail.topic
            content = detail.content
        } catch {
            generateError = error.localizedDescription
        }
        isLoadingExisting = false
    }

    private func generate() async {
        generateError = nil
        let trimmedSubject = subject.trimmingCharacters(in: .whitespaces)
        let trimmedGrade = gradeLevel.trimmingCharacters(in: .whitespaces)
        let trimmedTopic = topic.trimmingCharacters(in: .whitespaces)
        guard !trimmedSubject.isEmpty, !trimmedGrade.isEmpty, !trimmedTopic.isEmpty else {
            generateError = Loc.t("err_lesson_prep_fields_required")
            return
        }
        isGenerating = true
        do {
            let result = try await APIClient.shared.generateHomeworkHelp(subject: trimmedSubject, gradeLevel: trimmedGrade, topic: trimmedTopic, lang: settings.languageCode)
            savedId = nil
            content = result
        } catch {
            generateError = error.localizedDescription.isEmpty ? Loc.t("err_lesson_prep_gen_failed") : error.localizedDescription
        }
        isGenerating = false
    }

    private func copyToClipboard() {
        guard let content else { return }
        let lines = [
            "\(Loc.t("hh_explanation_label")):", content.explanation,
            "", "\(Loc.t("hh_example_label")):", content.workedExample,
            "", "\(Loc.t("hh_practice_label")):",
        ] + content.practiceQuestions.enumerated().map { "\($0.offset + 1). \($0.element.question)\n   \($0.element.answer)" } + [
            "", "\(Loc.t("hh_tips_label")):", content.tips,
        ]
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copyButtonLabel = Loc.t("copied_label")
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copyButtonLabel = Loc.t("btn_copy_lesson_prep")
        }
    }

    /// ما فيه PATCH لهذي الأداة بالباك إند - "حفظ" دايمًا POST (ينشئ جلسة
    /// جديدة)، حتى لو كنا نعرض جلسة محفوظة قبل.
    private func save() async {
        saveError = nil
        guard let content else { return }
        let trimmedSubject = subject.trimmingCharacters(in: .whitespaces)
        let trimmedGrade = gradeLevel.trimmingCharacters(in: .whitespaces)
        let trimmedTopic = topic.trimmingCharacters(in: .whitespaces)
        guard !trimmedSubject.isEmpty, !trimmedGrade.isEmpty, !trimmedTopic.isEmpty else {
            saveError = Loc.t("err_lesson_prep_fields_required")
            return
        }
        isSaving = true
        do {
            let saved = try await APIClient.shared.saveHomeworkHelp(subject: trimmedSubject, gradeLevel: trimmedGrade, topic: trimmedTopic, content: content)
            savedId = saved.id
            await onSaved()
            saveButtonLabel = Loc.t("saved_label")
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                saveButtonLabel = Loc.t("btn_save_homework_help")
            }
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    private func delete() async {
        guard let savedId else { return }
        isDeleting = true
        do {
            try await APIClient.shared.deleteHomeworkHelp(id: savedId)
            await onSaved()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isDeleting = false
    }
}
