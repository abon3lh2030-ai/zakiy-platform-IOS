import SwiftUI
import UniformTypeIdentifiers

/// صفحة واجب وحد - محتواه تحت العنوان، وتحته: عرض المعلم (حالة كل طالب +
/// تصحيح) أو عرض الطالب (حل الواجب أو حالة تسليمه لو سلّم فعلًا).
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
                            TeacherSubmissionsSection(assignmentId: assignmentId, students: assignment.students ?? [])
                        } else {
                            StudentSubmissionSection(assignmentId: assignmentId, submission: assignment.submission) {
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

// MARK: - عرض المعلم: حالة كل طالب + تصحيح

private struct TeacherSubmissionsSection: View {
    let assignmentId: String
    let students: [AssignmentStudentStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.t("assignment_students_heading")).font(.headline)
            if students.isEmpty {
                Text(Loc.t("assignment_no_students")).foregroundStyle(.secondary).font(.footnote)
            } else {
                ForEach(students) { student in
                    StudentSubmissionRow(assignmentId: assignmentId, student: student)
                }
            }
        }
    }
}

private struct StudentSubmissionRow: View {
    let assignmentId: String
    let student: AssignmentStudentStatus

    @State private var gradeText: String
    @State private var isSaving = false

    init(assignmentId: String, student: AssignmentStudentStatus) {
        self.assignmentId = assignmentId
        self.student = student
        _gradeText = State(initialValue: student.grade ?? "")
    }

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
                HStack {
                    Button(Loc.t("btn_view_file")) { Task { await viewFile() } }
                        .font(.caption)
                    Spacer()
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

    private func viewFile() async {
        guard let urlString = try? await APIClient.shared.teacherSubmissionFileURL(assignmentId: assignmentId, studentId: student.userId),
              let url = URL(string: urlString) else { return }
        await UIApplication.shared.open(url)
    }

    private func saveGrade() async {
        isSaving = true
        try? await APIClient.shared.gradeAssignmentSubmission(assignmentId: assignmentId, studentId: student.userId, grade: gradeText)
        isSaving = false
    }
}

// MARK: - عرض الطالب: حل الواجب أو حالة التسليم

private struct StudentSubmissionSection: View {
    let assignmentId: String
    let submission: AssignmentSubmission?
    var onSubmitted: () async -> Void

    @State private var pickedFileURL: URL?
    @State private var note = ""
    @State private var showFilePicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let submission {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Loc.t("assignment_submitted_file_label", submission.fileName))
                    if let note = submission.note, !note.isEmpty {
                        Text(Loc.t("assignment_note_shown", note))
                    }
                    Text(submission.grade.map { Loc.t("assignment_grade_shown", $0) } ?? Loc.t("assignment_not_graded_yet"))
                        .foregroundStyle(submission.grade == nil ? .secondary : .primary)
                }
                .font(.subheadline)
                .padding(12)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 10))
            } else {
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
                    Task { await submit() }
                } label: {
                    if isSubmitting { ProgressView().frame(maxWidth: .infinity) }
                    else { Text(Loc.t("btn_submit_assignment")).frame(maxWidth: .infinity) }
                }
                .buttonStyle(.appPrimary)
                .disabled(pickedFileURL == nil || isSubmitting)
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result { pickedFileURL = url }
        }
    }

    private func submit() async {
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
}
