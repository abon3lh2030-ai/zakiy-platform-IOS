import SwiftUI
import UIKit

/// تحضير درس بالذكاء الاصطناعي - إنشاء/عرض/تعديل/حذف (معلم). `existingId`
/// غير nil يعني نفتح تحضير محفوظ (نحمّله كامل بأول ظهور)، nil يعني تحضير
/// جديد فاضي. توليد جديد فوق تحضير محفوظ يفصل "المعرّف المحفوظ" عن الشاشة -
/// نفس سلوك `currentLessonPrepId = null` بموقع الويب بالضبط.
struct LessonPrepView: View {
    let existingId: String?
    var onSaved: () async -> Void = {}

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var savedId: String?
    @State private var subject = ""
    @State private var gradeLevel = ""
    @State private var unit = ""
    @State private var lessonTitle = ""
    @State private var content: LessonPrepContent?

    @State private var isLoadingExisting: Bool
    @State private var isGenerating = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var generateError: String?
    @State private var saveError: String?
    @State private var showDeleteConfirm = false
    @State private var saveButtonLabel: String
    @State private var copyButtonLabel: String

    init(existingId: String?, onSaved: @escaping () async -> Void = {}) {
        self.existingId = existingId
        self.onSaved = onSaved
        _savedId = State(initialValue: existingId)
        _isLoadingExisting = State(initialValue: existingId != nil)
        _saveButtonLabel = State(initialValue: Loc.t("btn_save_lesson_prep"))
        _copyButtonLabel = State(initialValue: Loc.t("btn_copy_lesson_prep"))
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
                        else { Text(Loc.t("btn_generate_lesson_prep")).frame(maxWidth: .infinity) }
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
        .navigationTitle(existingId != nil ? Loc.t("lesson_prep_view_heading") : Loc.t("lesson_prep_create_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .task { if let existingId { await loadExisting(existingId) } }
        .confirmationDialog(Loc.t("confirm_delete_lesson_prep"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
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
            TextField(Loc.t("ph_lesson_prep_unit"), text: $unit)
                .textFieldStyle(.roundedBorder)
            TextField(Loc.t("ph_lesson_prep_title"), text: $lessonTitle)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func resultSection(_ content: LessonPrepContent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledBulletList(label: Loc.t("lp_objectives_label"), items: content.objectives)
            LabeledTextBlock(label: Loc.t("lp_intro_label"), text: content.intro)
            LabeledBulletList(label: Loc.t("lp_steps_label"), items: content.steps)
            LabeledBulletList(label: Loc.t("lp_activities_label"), items: content.activities)
            LabeledTextBlock(label: Loc.t("lp_assessment_label"), text: content.assessment)
            LabeledTextBlock(label: Loc.t("lp_homework_label"), text: content.homework)
            LabeledTextBlock(label: Loc.t("lp_enrichment_label"), text: content.enrichment)
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
            let detail = try await APIClient.shared.lessonPrepDetail(id: id)
            subject = detail.subject
            gradeLevel = detail.gradeLevel
            unit = detail.unit ?? ""
            lessonTitle = detail.lessonTitle
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
        let trimmedTitle = lessonTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedSubject.isEmpty, !trimmedGrade.isEmpty, !trimmedTitle.isEmpty else {
            generateError = Loc.t("err_lesson_prep_fields_required")
            return
        }
        isGenerating = true
        do {
            let result = try await APIClient.shared.generateLessonPrep(
                subject: trimmedSubject, gradeLevel: trimmedGrade,
                unit: unit.trimmingCharacters(in: .whitespaces), lessonTitle: trimmedTitle,
                lang: settings.languageCode
            )
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
            "\(Loc.t("lp_objectives_label")):"] + content.objectives.map { "- \($0)" } + [
            "", "\(Loc.t("lp_intro_label")):", content.intro,
            "", "\(Loc.t("lp_steps_label")):"] + content.steps.map { "- \($0)" } + [
            "", "\(Loc.t("lp_activities_label")):"] + content.activities.map { "- \($0)" } + [
            "", "\(Loc.t("lp_assessment_label")):", content.assessment,
            "", "\(Loc.t("lp_homework_label")):", content.homework,
            "", "\(Loc.t("lp_enrichment_label")):", content.enrichment,
        ]
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copyButtonLabel = Loc.t("copied_label")
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copyButtonLabel = Loc.t("btn_copy_lesson_prep")
        }
    }

    private func save() async {
        saveError = nil
        guard let content else { return }
        let trimmedSubject = subject.trimmingCharacters(in: .whitespaces)
        let trimmedGrade = gradeLevel.trimmingCharacters(in: .whitespaces)
        let trimmedTitle = lessonTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedSubject.isEmpty, !trimmedGrade.isEmpty, !trimmedTitle.isEmpty else {
            saveError = Loc.t("err_lesson_prep_fields_required")
            return
        }
        isSaving = true
        do {
            let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
            if let savedId {
                _ = try await APIClient.shared.updateLessonPrep(id: savedId, subject: trimmedSubject, gradeLevel: trimmedGrade, unit: trimmedUnit, lessonTitle: trimmedTitle, content: content)
            } else {
                let saved = try await APIClient.shared.saveLessonPrep(subject: trimmedSubject, gradeLevel: trimmedGrade, unit: trimmedUnit, lessonTitle: trimmedTitle, content: content)
                savedId = saved.id
            }
            await onSaved()
            saveButtonLabel = Loc.t("saved_label")
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                saveButtonLabel = Loc.t("btn_save_lesson_prep")
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
            try await APIClient.shared.deleteLessonPrep(id: savedId)
            await onSaved()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - عناصر عرض مشتركة (تحضير الدرس/مساعد الواجب/خطة المذاكرة)

/// عنوان قسم + قائمة نقطية - لو القائمة فاضية ما يعرض القسم إطلاقًا
struct LabeledBulletList: View {
    let label: String
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.subheadline.weight(.semibold))
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        Text(item)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

/// عنوان قسم + نص فقرة - لو النص فاضي ما يعرض القسم إطلاقًا
struct LabeledTextBlock: View {
    let label: String
    let text: String

    var body: some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.subheadline.weight(.semibold))
                Text(text).font(.subheadline)
            }
        }
    }
}
