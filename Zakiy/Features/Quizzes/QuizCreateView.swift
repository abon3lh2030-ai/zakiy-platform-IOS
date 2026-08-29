import SwiftUI

/// نموذج إنشاء اختبار جديد أو تعديل مسودة موجودة - معلم بس. يجيب فصوله من
/// نفس مصدر TeacherRosterView (`/api/teacher/roster`) عند الإنشاء، وباني
/// أسئلة ديناميكي (إضافة/حذف سؤال، نوعه، اختياراته لو MCQ). تعليم الإجابة
/// الصحيحة اختياري دايمًا - لو ما اتعلّمت يصير السؤال محتاج تصحيح يدوي.
struct QuizCreateView: View {
    var editing: QuizDetail?
    var onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var classes: [SchoolClass] = []
    @State private var selectedClassId: String?
    @State private var subject: String
    @State private var title: String
    @State private var timeLimitMinutes: Int
    @State private var questions: [QuizQuestionDraft]
    /// المنصة تُختار وقت الإنشاء بس - شاشة التعديل (مسودة قبل النشر) ما تغيّرها،
    /// رابط مدرستي نفسه يُدار من شاشة التفصيل (PlatformLinkEditor) دايمًا
    @State private var platform: String
    @State private var externalLink = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { editing != nil }
    /// المنصة الفعلية المعتمدة بالفورم - مقفلة على قيمة الاختبار الموجود لو تعديل
    private var effectivePlatform: String { isEditing ? (editing?.platform ?? "zakiy") : platform }

    init(editing: QuizDetail? = nil, onSaved: @escaping () async -> Void) {
        self.editing = editing
        self.onSaved = onSaved
        _subject = State(initialValue: editing?.subject ?? "")
        _title = State(initialValue: editing?.title ?? "")
        _timeLimitMinutes = State(initialValue: editing?.timeLimitMinutes ?? 20)
        _selectedClassId = State(initialValue: editing?.classId)
        _platform = State(initialValue: editing?.platform ?? "zakiy")
        _questions = State(initialValue: editing?.questions
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(QuizQuestionDraft.init(from:)) ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section {
                        Picker(Loc.t("quiz_class_label"), selection: $selectedClassId) {
                            ForEach(classes) { c in Text(c.name).tag(Optional(c.id)) }
                        }
                    }
                }

                Section {
                    TextField(Loc.t("quiz_subject_placeholder"), text: $subject)
                        .accessibilityIdentifier("quiz_create_subject_field")
                    TextField(Loc.t("quiz_title_placeholder"), text: $title)
                        .accessibilityIdentifier("quiz_create_title_field")
                    if effectivePlatform == "zakiy" {
                        Stepper(Loc.t("quiz_time_limit_stepper_label", timeLimitMinutes), value: $timeLimitMinutes, in: 1...300)
                    }
                }

                if !isEditing {
                    Section {
                        PlatformPickerField(platform: $platform, externalLink: $externalLink)
                    }
                }

                if effectivePlatform == "zakiy" {
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
                        .accessibilityIdentifier("quiz_create_add_question_button")
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().frame(maxWidth: .infinity) }
                        else { Text(isEditing ? Loc.t("btn_save_changes") : Loc.t("btn_create_quiz")).frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.appPrimary)
                    .disabled(isSaving || subject.isEmpty || title.isEmpty || (!isEditing && selectedClassId == nil))
                    .accessibilityIdentifier("quiz_create_submit_button")
                }
            }
            .navigationTitle(isEditing ? Loc.t("quiz_edit_heading") : Loc.t("quiz_new_heading"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("cancel")) { dismiss() }
                }
            }
            .task { if !isEditing { await loadRoster() } }
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

    private func save() async {
        errorMessage = nil
        var payloads: [[String: Any]]?
        if effectivePlatform == "zakiy" {
            let built = questions.compactMap { $0.toPayload() }
            guard !built.isEmpty else {
                errorMessage = Loc.t("err_quiz_need_question")
                return
            }
            payloads = built
        }
        isSaving = true
        do {
            if let editing {
                _ = try await APIClient.shared.updateQuiz(
                    id: editing.id, subject: subject, title: title,
                    timeLimitMinutes: effectivePlatform == "zakiy" ? timeLimitMinutes : nil,
                    questions: payloads
                )
            } else {
                guard let selectedClassId else {
                    errorMessage = Loc.t("err_quiz_need_class")
                    isSaving = false
                    return
                }
                _ = try await APIClient.shared.createQuiz(
                    classId: selectedClassId, subject: subject, title: title,
                    timeLimitMinutes: platform == "zakiy" ? timeLimitMinutes : nil,
                    questions: payloads, platform: platform,
                    externalLink: externalLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : externalLink
                )
            }
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - حالة سؤال محلية أثناء البناء (قبل تحويله لقاموس الطلب) - غير
// private عشان AssignmentCreateSheet يعيد استخدامها لأسئلة واجب نوع
// "questions" (نفس شكل الطلب بالضبط لصنفي الأسئلة).

struct QuizQuestionDraft: Identifiable {
    let id = UUID()
    var questionType: String = "mcq"
    var text: String = ""
    var choices: [String] = ["", ""]
    var correctChoiceIndex: Int?
    var correctBool: Bool?

    init() {}

    init(from q: QuizQuestionFull) {
        questionType = q.questionType
        text = q.questionText
        if q.questionType == "mcq" {
            let existing = q.choices ?? []
            choices = existing.count >= 2 ? existing : ["", ""]
            if let correct = q.correctAnswer, let idx = choices.firstIndex(of: correct) {
                correctChoiceIndex = idx
            }
        }
        if q.questionType == "true_false" {
            correctBool = q.correctAnswer == "true" ? true : (q.correctAnswer == "false" ? false : nil)
        }
    }

    /// يبني قاموس الطلب بشكل `{question_type, question_text, choices,
    /// correct_answer}` - يرجّع nil لو نص السؤال فاضي (سؤال ما يستاهل يُرسل)
    func toPayload() -> [String: Any]? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return nil }
        var dict: [String: Any] = ["question_type": questionType, "question_text": trimmedText]
        switch questionType {
        case "mcq":
            let cleanChoices = choices.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            dict["choices"] = cleanChoices
            if let idx = correctChoiceIndex, idx < choices.count {
                let chosen = choices[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                dict["correct_answer"] = cleanChoices.contains(chosen) ? chosen : NSNull()
            } else {
                dict["correct_answer"] = NSNull()
            }
        case "true_false":
            dict["choices"] = NSNull()
            dict["correct_answer"] = correctBool.map { $0 ? "true" : "false" } ?? NSNull()
        default: // essay
            dict["choices"] = NSNull()
            dict["correct_answer"] = NSNull()
        }
        return dict
    }
}

// MARK: - محرر سؤال واحد - غير private (نفس سبب QuizQuestionDraft فوق)

struct QuestionEditorCard: View {
    @Binding var question: QuizQuestionDraft
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker(Loc.t("quiz_question_type_label"), selection: $question.questionType) {
                    Text(Loc.t("quiz_type_mcq")).tag("mcq")
                    Text(Loc.t("quiz_type_true_false")).tag("true_false")
                    Text(Loc.t("quiz_type_essay")).tag("essay")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("question_editor_type_picker")
                Spacer()
                Button(role: .destructive) { onRemove() } label: {
                    Image(systemName: "trash")
                }
            }

            TextField(Loc.t("quiz_question_text_placeholder"), text: $question.text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("question_editor_text_field")

            switch question.questionType {
            case "mcq": mcqEditor
            case "true_false": trueFalseEditor
            default: EmptyView()
            }
        }
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
    }

    private var mcqEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Loc.t("quiz_mark_correct_hint")).font(.caption).foregroundStyle(.secondary)
            ForEach(Array(question.choices.indices), id: \.self) { idx in
                HStack {
                    Button {
                        question.correctChoiceIndex = (question.correctChoiceIndex == idx) ? nil : idx
                    } label: {
                        Image(systemName: question.correctChoiceIndex == idx ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.plain)

                    TextField(Loc.t("quiz_choice_placeholder", idx + 1), text: Binding(
                        get: { question.choices[idx] },
                        set: { question.choices[idx] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    if question.choices.count > 2 {
                        Button { removeChoice(at: idx) } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button(Loc.t("btn_add_choice")) {
                question.choices.append("")
            }
            .font(.caption)
        }
    }

    private func removeChoice(at index: Int) {
        question.choices.remove(at: index)
        if let idx = question.correctChoiceIndex {
            if idx == index { question.correctChoiceIndex = nil }
            else if idx > index { question.correctChoiceIndex = idx - 1 }
        }
    }

    private var trueFalseEditor: some View {
        HStack(spacing: 16) {
            Button {
                question.correctBool = (question.correctBool == true) ? nil : true
            } label: {
                Label(Loc.t("quiz_true_label"), systemImage: question.correctBool == true ? "checkmark.circle.fill" : "circle")
            }
            .accessibilityIdentifier("question_editor_true_button")
            Button {
                question.correctBool = (question.correctBool == false) ? nil : false
            } label: {
                Label(Loc.t("quiz_false_label"), systemImage: question.correctBool == false ? "checkmark.circle.fill" : "circle")
            }
            .accessibilityIdentifier("question_editor_false_button")
        }
        .buttonStyle(.plain)
        .font(.subheadline)
    }
}
