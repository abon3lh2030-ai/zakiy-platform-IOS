import SwiftUI
import UniformTypeIdentifiers

/// صفحة واجب وحد - محتواه تحت العنوان، وتحته: عرض المعلم (حالة كل طالب +
/// تصحيح) أو عرض الطالب (حل الواجب أو حالة تسليمه لو سلّم فعلًا). واجب منصة
/// "مدرستي" ما له عرض حل/تسليم داخل ذكّي إطلاقًا - بس رابط + زر فتح مباشر.
struct AssignmentDetailView: View {
    let assignmentId: String
    let isTeacher: Bool

    @State private var assignment: AssignmentDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let assignment {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(assignment.subject).font(.caption).foregroundStyle(.secondary)
                            Text(assignment.title).font(.title2.weight(.bold))
                            if !assignment.content.isEmpty {
                                Text(assignment.content).font(.body).padding(.top, 4)
                            }
                        }

                        Divider()

                        if isTeacher {
                            TeacherSubmissionsSection(assignmentId: assignmentId, assignment: assignment) {
                                await load()
                            }
                        } else {
                            StudentSubmissionSection(assignmentId: assignmentId, assignment: assignment) {
                                await load()
                            }
                        }
                    }
                    .padding()
                }
            } else if let errorMessage {
                ContentUnavailableView(Loc.t("assignments"), systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            assignment = isTeacher
                ? try await APIClient.shared.teacherAssignmentDetail(id: assignmentId)
                : try await APIClient.shared.studentAssignmentDetail(id: assignmentId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - عرض المعلم: حالة كل طالب + تصحيح، أو محرر رابط مدرستي

private struct TeacherSubmissionsSection: View {
    let assignmentId: String
    let assignment: AssignmentDetail
    var onLinkUpdated: () async -> Void

    @State private var linkError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if assignment.platform == "madrasati" {
                PlatformLinkEditor(currentLink: assignment.externalLink) { newLink in
                    let trimmed = newLink.trimmingCharacters(in: .whitespacesAndNewlines)
                    linkError = nil
                    do {
                        try await APIClient.shared.updateAssignmentLink(id: assignmentId, externalLink: trimmed.isEmpty ? nil : trimmed)
                        await onLinkUpdated()
                    } catch {
                        // كانت `try?` تبلع الفشل - المعلم يشوف الحفظ يخلص عادي
                        // بدون أي إشارة إن الرابط ما انحفظ فعليًا بالسيرفر
                        linkError = Loc.t("error_generic")
                    }
                }
                if let linkError {
                    Text(linkError).font(.caption).foregroundStyle(.red)
                        .accessibilityIdentifier("assignment_link_error")
                }
            } else {
                Text(Loc.t("assignment_students_heading")).font(.headline)
                let students = assignment.students ?? []
                if students.isEmpty {
                    Text(Loc.t("assignment_no_students")).foregroundStyle(.secondary).font(.footnote)
                } else {
                    ForEach(students) { student in
                        StudentSubmissionRow(
                            assignmentId: assignmentId,
                            submissionType: assignment.submissionType,
                            questions: assignment.questions ?? [],
                            student: student
                        )
                    }
                }
            }
        }
    }
}

private struct StudentSubmissionRow: View {
    let assignmentId: String
    let submissionType: String
    let questions: [QuizQuestionFull]
    let student: AssignmentStudentStatus

    @State private var gradeText: String
    @State private var isSaving = false
    @State private var isExpanded = false
    @State private var gradeError: String?

    init(assignmentId: String, submissionType: String, questions: [QuizQuestionFull], student: AssignmentStudentStatus) {
        self.assignmentId = assignmentId
        self.submissionType = submissionType
        self.questions = questions
        self.student = student
        _gradeText = State(initialValue: student.grade ?? "")
    }

    private var sortedQuestions: [QuizQuestionFull] { questions.sorted { $0.orderIndex < $1.orderIndex } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(student.fullName ?? student.username).font(.subheadline.weight(.medium))
                Spacer()
                Text(student.submitted ? Loc.t("assignment_status_done") : Loc.t("assignment_status_pending"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(student.submitted ? Color.green : Color.orange)
            }
            if student.submitted {
                if submissionType == "questions" {
                    questionsAnswersView
                } else {
                    HStack {
                        Button(Loc.t("btn_view_file")) { Task { await viewFile() } }
                            .font(.caption)
                        Spacer()
                        gradeField
                    }
                }
            }
        }
        .padding(10)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var questionsAnswersView: some View {
        HStack {
            Button(isExpanded ? Loc.t("assignment_hide_answers") : Loc.t("assignment_view_answers")) {
                withAnimation { isExpanded.toggle() }
            }
            .font(.caption)
            Spacer()
            if student.isAutoGraded == true, let score = student.score, let total = student.totalQuestions {
                Text("\(score)/\(total)").font(.caption).foregroundStyle(.secondary)
            }
        }

        if isExpanded {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(sortedQuestions) { q in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(q.questionText).font(.footnote.weight(.medium))
                        Text(Loc.t("quiz_student_answer_label", displayAnswer(student.answers?[q.id], type: q.questionType)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let correct = q.correctAnswer {
                            Text(Loc.t("quiz_correct_answer_label", displayAnswer(correct, type: q.questionType)))
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 8))
        }

        HStack {
            gradeField
        }
    }

    private var gradeField: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack {
                TextField(Loc.t("assignment_grade_label"), text: $gradeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .accessibilityIdentifier("assignment_grade_field_\(student.userId)")
                Button(Loc.t("btn_save_grade")) { Task { await saveGrade() } }
                    .font(.caption)
                    .disabled(isSaving)
                    .accessibilityIdentifier("assignment_save_grade_button_\(student.userId)")
            }
            if let gradeError {
                Text(gradeError).font(.caption2).foregroundStyle(.red)
                    .accessibilityIdentifier("assignment_grade_error_\(student.userId)")
            }
        }
    }

    /// صح/خطأ يترجمون لعربي، غير كذا النص يرجع زي ما هو (أو "بدون إجابة" لو nil)
    private func displayAnswer(_ raw: String?, type: String) -> String {
        guard let raw else { return Loc.t("quiz_no_answer") }
        guard type == "true_false" else { return raw }
        if raw == "true" { return Loc.t("quiz_true_label") }
        if raw == "false" { return Loc.t("quiz_false_label") }
        return raw
    }

    private func viewFile() async {
        guard let urlString = try? await APIClient.shared.teacherSubmissionFileURL(assignmentId: assignmentId, studentId: student.userId),
              let url = URL(string: urlString) else { return }
        await UIApplication.shared.open(url)
    }

    private func saveGrade() async {
        isSaving = true
        gradeError = nil
        do {
            try await APIClient.shared.gradeAssignmentSubmission(assignmentId: assignmentId, studentId: student.userId, grade: gradeText)
        } catch {
            // كانت `try?` تبلع الفشل بصمت - المعلم يشوف الزر يرجع عادي بدون
            // أي إشارة إن الدرجة ما انحفظت فعليًا بالسيرفر
            gradeError = Loc.t("error_generic")
        }
        isSaving = false
    }
}

// MARK: - عرض الطالب: حل الواجب (ملف/أسئلة)، حالة التسليم، أو فتح مدرستي

private struct StudentSubmissionSection: View {
    let assignmentId: String
    let assignment: AssignmentDetail
    var onSubmitted: () async -> Void

    @State private var pickedFileURL: URL?
    @State private var note = ""
    @State private var answers: [String: String] = [:]
    @State private var showFilePicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var sortedQuestions: [QuizQuestionFull] {
        (assignment.questions ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if assignment.platform == "madrasati" {
                OpenOnMadrasatiView(externalLink: assignment.externalLink)
            } else if let submission = assignment.submission {
                submittedView(submission)
            } else if assignment.submissionType == "questions" {
                questionsSubmitView
            } else {
                fileSubmitView
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result { pickedFileURL = url }
        }
    }

    @ViewBuilder
    private func submittedView(_ submission: AssignmentSubmission) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let fileName = submission.fileName {
                Text(Loc.t("assignment_submitted_file_label", fileName))
            }
            if let note = submission.note, !note.isEmpty {
                Text(Loc.t("assignment_note_shown", note))
            }
            if submission.isAutoGraded == true, let score = submission.score, let total = submission.totalQuestions {
                Text(Loc.t("assignment_score_format", score, total))
            }
            Text(submission.grade.map { Loc.t("assignment_grade_shown", $0) } ?? Loc.t("assignment_not_graded_yet"))
                .foregroundStyle(submission.grade == nil ? .secondary : .primary)
        }
        .font(.subheadline)
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 10))
    }

    private var questionsSubmitView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Loc.t("assignment_submit_heading")).font(.headline)

            ForEach(sortedQuestions) { question in
                QuestionAnswerCard(question: question, answer: answerBinding(for: question.id))
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }

            Button {
                Task { await submitAnswers() }
            } label: {
                if isSubmitting { ProgressView().frame(maxWidth: .infinity) }
                else { Text(Loc.t("btn_submit_assignment")).frame(maxWidth: .infinity) }
            }
            .buttonStyle(.appPrimary)
            .disabled(isSubmitting)
        }
    }

    private func answerBinding(for questionId: String) -> Binding<String> {
        Binding(
            get: { answers[questionId] ?? "" },
            set: { answers[questionId] = $0 }
        )
    }

    private var fileSubmitView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Loc.t("assignment_submit_heading")).font(.headline)

            Button {
                showFilePicker = true
            } label: {
                Label(pickedFileURL?.lastPathComponent ?? Loc.t("btn_pick_assignment_file"), systemImage: "paperclip")
            }
            .buttonStyle(.bordered)

            TextField(Loc.t("assignment_note_placeholder"), text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }

            Button {
                Task { await submitFile() }
            } label: {
                if isSubmitting { ProgressView().frame(maxWidth: .infinity) }
                else { Text(Loc.t("btn_submit_assignment")).frame(maxWidth: .infinity) }
            }
            .buttonStyle(.appPrimary)
            .disabled(pickedFileURL == nil || isSubmitting)
        }
    }

    private func submitFile() async {
        guard let pickedFileURL else { return }
        isSubmitting = true
        errorMessage = nil
        guard pickedFileURL.startAccessingSecurityScopedResource() else {
            errorMessage = Loc.t("error_generic")
            isSubmitting = false
            return
        }
        defer { pickedFileURL.stopAccessingSecurityScopedResource() }
        do {
            try await APIClient.shared.submitAssignment(id: assignmentId, fileURL: pickedFileURL, note: note)
            await onSubmitted()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func submitAnswers() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await APIClient.shared.submitAssignmentAnswers(id: assignmentId, answers: answers)
            await onSubmitted()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
