import SwiftUI
import UIKit

/// خطة مذاكرة ذكية (طالب) - إنشاء/عرض/حذف. الباك إند ما يوفّر PATCH لهذي
/// الأداة برضو، فـ"حفظ" دايمًا ينشئ خطة جديدة (POST) - نفس مبدأ مساعد الواجب.
struct StudyPlanView: View {
    let existingId: String?
    var onSaved: () async -> Void = {}

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var savedId: String?
    @State private var subjects = ""
    @State private var includeExamDate = false
    @State private var examDate = Date()
    @State private var hoursPerDay = ""
    @State private var content: StudyPlanContent?

    @State private var isLoadingExisting: Bool
    @State private var isGenerating = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var generateError: String?
    @State private var saveError: String?
    @State private var showDeleteConfirm = false
    @State private var saveButtonLabel = Loc.t("btn_save_study_plan")
    @State private var copyButtonLabel = Loc.t("btn_copy_lesson_prep")

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

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
                        else { Text(Loc.t("btn_generate_study_plan")).frame(maxWidth: .infinity) }
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
        .navigationTitle(existingId != nil ? Loc.t("study_plan_view_heading") : Loc.t("study_plan_create_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .task { if let existingId { await loadExisting(existingId) } }
        .confirmationDialog(Loc.t("confirm_delete_study_plan"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(Loc.t("delete"), role: .destructive) { Task { await delete() } }
            Button(Loc.t("cancel"), role: .cancel) {}
        }
    }

    private var formSection: some View {
        VStack(spacing: 10) {
            TextField(Loc.t("ph_study_plan_subjects"), text: $subjects)
                .textFieldStyle(.roundedBorder)

            Toggle(Loc.t("study_plan_exam_date_toggle"), isOn: $includeExamDate.animation())
            if includeExamDate {
                DatePicker(Loc.t("study_plan_exam_date_label"), selection: $examDate, displayedComponents: .date)
            }

            TextField(Loc.t("ph_study_plan_hours"), text: $hoursPerDay)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
        }
    }

    @ViewBuilder
    private func resultSection(_ content: StudyPlanContent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(content.days.enumerated()), id: \.offset) { _, day in
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.dateLabel).font(.subheadline.weight(.semibold))
                    ForEach(Array(day.tasks.enumerated()), id: \.offset) { _, task in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(task)
                        }
                        .font(.subheadline)
                    }
                }
            }
            LabeledTextBlock(label: Loc.t("sp_tips_label"), text: content.generalTips)
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
            let detail = try await APIClient.shared.studyPlanDetail(id: id)
            subjects = detail.subjects
            if let examDateString = detail.examDate, let parsed = Self.dateFormatter.date(from: examDateString) {
                includeExamDate = true
                examDate = parsed
            }
            if let hours = detail.hoursPerDay {
                hoursPerDay = hours.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(hours)) : String(hours)
            }
            content = detail.content
        } catch {
            generateError = error.localizedDescription
        }
        isLoadingExisting = false
    }

    private func generate() async {
        generateError = nil
        let trimmedSubjects = subjects.trimmingCharacters(in: .whitespaces)
        guard !trimmedSubjects.isEmpty else {
            generateError = Loc.t("err_study_plan_subjects_required")
            return
        }
        isGenerating = true
        do {
            let result = try await APIClient.shared.generateStudyPlan(
                subjects: trimmedSubjects,
                examDate: includeExamDate ? Self.dateFormatter.string(from: examDate) : nil,
                hoursPerDay: Double(hoursPerDay),
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
        var lines: [String] = []
        for day in content.days {
            lines.append("\(day.dateLabel):")
            lines.append(contentsOf: day.tasks.map { "- \($0)" })
            lines.append("")
        }
        lines.append("\(Loc.t("sp_tips_label")):")
        lines.append(content.generalTips)
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copyButtonLabel = Loc.t("copied_label")
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copyButtonLabel = Loc.t("btn_copy_lesson_prep")
        }
    }

    /// ما فيه PATCH لهذي الأداة بالباك إند - "حفظ" دايمًا POST (ينشئ خطة
    /// جديدة)، حتى لو كنا نعرض خطة محفوظة قبل.
    private func save() async {
        saveError = nil
        guard let content else { return }
        let trimmedSubjects = subjects.trimmingCharacters(in: .whitespaces)
        guard !trimmedSubjects.isEmpty else {
            saveError = Loc.t("err_study_plan_subjects_required")
            return
        }
        isSaving = true
        do {
            let saved = try await APIClient.shared.saveStudyPlan(
                subjects: trimmedSubjects,
                examDate: includeExamDate ? Self.dateFormatter.string(from: examDate) : nil,
                hoursPerDay: Double(hoursPerDay),
                content: content
            )
            savedId = saved.id
            await onSaved()
            saveButtonLabel = Loc.t("saved_label")
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                saveButtonLabel = Loc.t("btn_save_study_plan")
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
            try await APIClient.shared.deleteStudyPlan(id: savedId)
            await onSaved()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isDeleting = false
    }
}
