import SwiftUI

/// نموذج إنشاء واجب جديد - معلم بس. يجيب فصوله من نفس مصدر TeacherRosterView
/// (`/api/teacher/roster`) ويختار فصل - الواجب دايمًا لكل طلاب الفصل (ما فيه
/// خيار استهداف طالب معيّن، الباك إند ما يدعمه بعد الآن).
struct AssignmentCreateSheet: View {
    var onCreated: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var classes: [SchoolClass] = []
    @State private var selectedClassId: String?
    @State private var subject = ""
    @State private var title = ""
    @State private var content = ""
    @State private var platform = "zakiy"
    @State private var externalLink = ""
    @State private var submissionType = "file"
    @State private var questions: [QuizQuestionDraft] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(Loc.t("assignment_class_label"), selection: $selectedClassId) {
                        ForEach(classes) { c in Text(c.name).tag(Optional(c.id)) }
                    }
                }
                Section {
                    TextField(Loc.t("assignment_subject_placeholder"), text: $subject)
                        .accessibilityIdentifier("assignment_create_subject_field")
                    TextField(Loc.t("assignment_title_placeholder"), text: $title)
                        .accessibilityIdentifier("assignment_create_title_field")
                    TextEditor(text: $content)
                        .accessibilityIdentifier("assignment_create_content_field")
                        .frame(minHeight: 140)
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text(Loc.t("assignment_content_placeholder"))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8).padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section {
                    PlatformPickerField(platform: $platform, externalLink: $externalLink)
                }

                if platform == "zakiy" {
                    Section {
                        Picker(Loc.t("submission_type_label"), selection: $submissionType) {
                            Text(Loc.t("submission_type_file")).tag("file")
                            Text(Loc.t("submission_type_questions")).tag("questions")
                        }
                        .pickerStyle(.segmented)
                    }

                    if submissionType == "questions" {
                        Section(Loc.t("quiz_questions_heading")) {
                            ForEach($questions) { $question in
                                QuestionEditorCard(question: $question, onRemove: { removeQuestion(id: question.id) })
                                    .listRowInsets(EdgeInsets())
                                    .padding(.vertical, 6)
                                    .listRowSeparator(.hidden)
                            }
                            Button(Loc.t("btn_add_question")) {
                                questions.append(QuizQuestionDraft())
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
                Section {
                    Button {
                        Task { await create() }
                    } label: {
                        if isSaving { ProgressView().frame(maxWidth: .infinity) }
                        else { Text(Loc.t("btn_create_assignment")).frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.appPrimary)
                    .disabled(isSaving || selectedClassId == nil || subject.isEmpty || title.isEmpty)
                    .accessibilityIdentifier("assignment_create_submit_button")
                }
            }
            .navigationTitle(Loc.t("assignment_new_heading"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("cancel")) { dismiss() }
                }
            }
            .task { await loadRoster() }
        }
    }

    private func loadRoster() async {
        let roster = try? await APIClient.shared.teacherRoster()
        classes = roster?.classes ?? []
        if selectedClassId == nil { selectedClassId = classes.first?.id }
    }

    private func removeQuestion(id: UUID) {
        questions.removeAll { $0.id == id }
    }

    private func create() async {
        guard let selectedClassId else {
            errorMessage = Loc.t("err_assignment_need_class")
            return
        }
        errorMessage = nil

        var questionPayloads: [[String: Any]]?
        if platform == "zakiy" && submissionType == "questions" {
            let payloads = questions.compactMap { $0.toPayload() }
            guard !payloads.isEmpty else {
                errorMessage = Loc.t("err_assignment_need_question")
                return
            }
            questionPayloads = payloads
        }

        isSaving = true
        do {
            try await APIClient.shared.createAssignment(
                classId: selectedClassId,
                subject: subject,
                title: title,
                content: content,
                submissionType: submissionType,
                questions: questionPayloads,
                platform: platform,
                externalLink: externalLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : externalLink
            )
            await onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
