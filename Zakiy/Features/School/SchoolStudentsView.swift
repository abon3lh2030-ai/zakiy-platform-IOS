import SwiftUI

/// كل طلاب المدرسة بأسمائهم الحقيقية الكاملة (لا بس اسم المستخدم المولّد) -
/// مع زر إعادة تعيين كلمة سر وزر حذف لكل طالب لحاله، بنفس نمط SchoolTeachersView.
struct SchoolStudentsView: View {
    @State private var students: [SchoolStudent] = []
    @State private var classes: [SchoolClass] = []
    @State private var isLoading = true

    @State private var resetResult: AccountResetCredentials?
    @State private var resetError: String?
    @State private var studentPendingReset: SchoolStudent?
    @State private var deleteError: String?
    @State private var studentPendingDelete: SchoolStudent?

    private var classNames: [String: String] {
        Dictionary(uniqueKeysWithValues: classes.map { ($0.id, $0.name) })
    }

    var body: some View {
        List {
            Section {
                if isLoading {
                    ProgressView()
                } else if students.isEmpty {
                    Text(Loc.t("no_students_in_school")).foregroundStyle(.secondary)
                } else {
                    ForEach(students) { student in
                        studentRow(student)
                    }
                }
                if let resetResult {
                    credentialResultBox(resetResult, title: Loc.t("reset_password_result_msg"))
                }
                if let resetError {
                    Text(resetError).font(.footnote).foregroundStyle(.red)
                }
                if let deleteError {
                    Text(deleteError).font(.footnote).foregroundStyle(.red)
                        .accessibilityIdentifier("school_students_delete_error")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func studentRow(_ student: SchoolStudent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(student.fullName?.isEmpty == false ? student.fullName! : student.username).font(.headline)
            if student.fullName?.isEmpty == false {
                Text(student.username).font(.caption).foregroundStyle(.secondary)
            }
            if let classId = student.classId, let name = classNames[classId] {
                Text(name).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button(Loc.t("btn_reset_password")) {
                    studentPendingReset = student
                }
                .font(.caption)
                // كان الحذف ينفّذ مباشرة بدون أي تأكيد (عكس زر إعادة تعيين
                // كلمة السر بنفس الصف اللي عنده confirmationDialog) - حذف
                // طالب فعلي بضغطة وحدة بالغلط خطر حقيقي، فأضفنا نفس نمط التأكيد.
                Button(Loc.t("btn_delete"), role: .destructive) {
                    studentPendingDelete = student
                }
                .font(.caption)
                .accessibilityIdentifier("school_student_delete_button_\(student.id)")
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            Loc.t("confirm_reset_account_password"),
            isPresented: Binding(get: { studentPendingReset?.id == student.id }, set: { if !$0 { studentPendingReset = nil } }),
            titleVisibility: .visible
        ) {
            Button(Loc.t("btn_reset_password")) {
                Task { await resetPassword(student) }
            }
            Button(Loc.t("cancel"), role: .cancel) { studentPendingReset = nil }
        }
        .confirmationDialog(
            Loc.t("confirm_delete_account"),
            isPresented: Binding(get: { studentPendingDelete?.id == student.id }, set: { if !$0 { studentPendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(Loc.t("btn_delete"), role: .destructive) {
                Task { await deleteStudent(student) }
            }
            Button(Loc.t("cancel"), role: .cancel) { studentPendingDelete = nil }
        }
    }

    private func load() async {
        isLoading = true
        async let studentsResult = APIClient.shared.schoolStudents()
        async let classesResult = APIClient.shared.schoolClasses()
        students = (try? await studentsResult) ?? []
        classes = (try? await classesResult) ?? []
        isLoading = false
    }

    private func resetPassword(_ student: SchoolStudent) async {
        resetError = nil
        resetResult = nil
        do {
            resetResult = try await APIClient.shared.schoolResetAccountPassword(userId: student.userId)
        } catch {
            resetError = Loc.t("error_generic")
        }
    }

    private func deleteStudent(_ student: SchoolStudent) async {
        deleteError = nil
        do {
            try await APIClient.shared.schoolDeleteAccount(userId: student.userId)
            await load()
        } catch {
            deleteError = Loc.t("error_generic")
        }
    }
}
