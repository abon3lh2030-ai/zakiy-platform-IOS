import SwiftUI

/// كل طلاب المدرسة بأسمائهم الحقيقية الكاملة (لا بس اسم المستخدم المولّد) -
/// مع زر إعادة تعيين كلمة سر لكل طالب لحاله، بنفس نمط SchoolTeachersView.
struct SchoolStudentsView: View {
    @State private var students: [SchoolStudent] = []
    @State private var classes: [SchoolClass] = []
    @State private var isLoading = true

    @State private var resetResult: AccountResetCredentials?
    @State private var resetError: String?
    @State private var studentPendingReset: SchoolStudent?

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
            Button(Loc.t("btn_reset_password")) {
                studentPendingReset = student
            }
            .font(.caption)
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
}
