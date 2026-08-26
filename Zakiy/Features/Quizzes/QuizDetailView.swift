import SwiftUI

/// صفحة اختبار وحد - منظور المعلم بس (منظور الطالب بـ QuizTakeView). مسودة:
/// أزرار تعديل/نشر/حذف. منشور: حالة كل طالب + عرض إجاباته + درجة يدوية
/// (تشتغل دايمًا، حتى لو صحح تلقائيًا - المعلم يقدر يعدّلها).
struct QuizDetailView: View {
    let quizId: String

    @Environment(\.dismiss) private var dismiss
    @State private var detail: QuizDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showEditSheet = false
    @State private var showPublishConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isPublishing = false
    @State private var isDeleting = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(detail)

                        if detail.platform == "madrasati" {
                            PlatformLinkEditor(currentLink: detail.externalLink) { newLink in
                                let trimmed = newLink.trimmingCharacters(in: .whitespacesAndNewlines)
                                _ = try? await APIClient.shared.updateQuizLink(id: quizId, externalLink: trimmed.isEmpty ? nil : trimmed)
                                await load()
                            }
                        }

                        if !detail.isPublished {
                            actionsRow
                        }

                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(.red).font(.footnote)
                        }

                        Divider()

                        if detail.isPublished && detail.platform == "zakiy" {
                            StudentsSection(quizId: quizId, questions: detail.questions, students: detail.students)
                        }
                    }
                    .padding()
                }
            } else if let errorMessage {
                ContentUnavailableView(Loc.t("quizzes"), systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showEditSheet) {
            if let detail {
                QuizCreateView(editing: detail) { await load() }
            }
        }
        .confirmationDialog(Loc.t("quiz_publish_confirm_title"), isPresented: $showPublishConfirm, titleVisibility: .visible) {
            Button(Loc.t("btn_publish_quiz")) { Task { await publish() } }
            Button(Loc.t("cancel"), role: .cancel) {}
        } message: {
            Text(Loc.t("quiz_publish_confirm_message"))
        }
        .confirmationDialog(Loc.t("quiz_delete_confirm_title"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(Loc.t("delete"), role: .destructive) { Task { await deleteQuiz() } }
            Button(Loc.t("cancel"), role: .cancel) {}
        } message: {
            Text(Loc.t("quiz_delete_confirm_message"))
        }
    }

    @ViewBuilder
    private func header(_ detail: QuizDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(detail.subject).font(.caption).foregroundStyle(.secondary)
            Text(detail.title).font(.title2.weight(.bold))
            HStack(spacing: 8) {
                if let timeLimitMinutes = detail.timeLimitMinutes {
                    Text(Loc.t("quiz_time_limit_minutes_format", timeLimitMinutes))
                    Text("•")
                } else {
                    Text(Loc.t("platform_madrasati_badge")).foregroundStyle(.brown)
                    Text("•")
                }
                Text(detail.isPublished ? Loc.t("quiz_status_published") : Loc.t("quiz_status_draft"))
                    .foregroundStyle(detail.isPublished ? Color.green : Color.orange)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            Button(Loc.t("edit")) { showEditSheet = true }
                .buttonStyle(.bordered)
            Button {
                showPublishConfirm = true
            } label: {
                if isPublishing { ProgressView() } else { Text(Loc.t("btn_publish_quiz")) }
            }
            .buttonStyle(.appPrimary)
            .disabled(isPublishing)
            Button(Loc.t("delete"), role: .destructive) { showDeleteConfirm = true }
                .buttonStyle(.bordered)
                .disabled(isDeleting)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.teacherQuizDetail(id: quizId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func publish() async {
        isPublishing = true
        do {
            _ = try await APIClient.shared.publishQuiz(id: quizId)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPublishing = false
    }

    private func deleteQuiz() async {
        isDeleting = true
        do {
            try await APIClient.shared.deleteQuiz(id: quizId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - حالة الطلاب (اختبار منشور بس)

private struct StudentsSection: View {
    let quizId: String
    let questions: [QuizQuestionFull]
    let students: [QuizStudentStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.t("quiz_students_heading")).font(.headline)
            if students.isEmpty {
                Text(Loc.t("quiz_no_students")).foregroundStyle(.secondary).font(.footnote)
            } else {
                ForEach(students) { student in
                    QuizStudentRow(quizId: quizId, questions: questions, student: student)
                }
            }
        }
    }
}

private struct QuizStudentRow: View {
    let quizId: String
    let questions: [QuizQuestionFull]
    let student: QuizStudentStatus

    @State private var isExpanded = false
    @State private var gradeText: String
    @State private var isSaving = false

    init(quizId: String, questions: [QuizQuestionFull], student: QuizStudentStatus) {
        self.quizId = quizId
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
                Text(student.submitted ? Loc.t("assignment_status_done") : Loc.t("quiz_status_not_taken"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(student.submitted ? Color.green : Color.orange)
            }

            if student.submitted {
                if student.autoSubmitted == true {
                    Text(Loc.t("quiz_auto_submitted_badge")).font(.caption2).foregroundStyle(.orange)
                }

                HStack {
                    Button(isExpanded ? Loc.t("quiz_hide_answers") : Loc.t("quiz_view_answers")) {
                        withAnimation { isExpanded.toggle() }
                    }
                    .font(.caption)
                    Spacer()
                    if student.isGraded, let score = student.score, let total = student.totalQuestions {
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
                    TextField(Loc.t("assignment_grade_label"), text: $gradeText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Button(Loc.t("btn_save_grade")) { Task { await saveGrade() } }
                        .font(.caption)
                        .disabled(isSaving)
                }
            }
        }
        .padding(10)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 10))
    }

    /// صح/خطأ يترجمون لعربي، غير كذا النص يرجع زي ما هو (أو "بدون إجابة" لو nil)
    private func displayAnswer(_ raw: String?, type: String) -> String {
        guard let raw else { return Loc.t("quiz_no_answer") }
        guard type == "true_false" else { return raw }
        if raw == "true" { return Loc.t("quiz_true_label") }
        if raw == "false" { return Loc.t("quiz_false_label") }
        return raw
    }

    private func saveGrade() async {
        isSaving = true
        try? await APIClient.shared.gradeQuizAttempt(quizId: quizId, studentId: student.userId, grade: gradeText)
        isSaving = false
    }
}
