import SwiftUI

struct SchoolTeachersView: View {
    @State private var teachers: [TeacherSummary] = []
    @State private var isLoading = true

    @State private var name = ""
    @State private var email = ""
    @State private var isSaving = false
    @State private var formError: String?
    @State private var credentialResult: GeneratedCredentials?

    @State private var broadcastBody = ""
    @State private var isBroadcasting = false
    @State private var broadcastMessage: String?

    @State private var resetResult: AccountResetCredentials?
    @State private var resetError: String?
    @State private var teacherPendingReset: TeacherSummary?

    var body: some View {
        List {
            Section(Loc.t("btn_add_teacher")) {
                TextField(Loc.t("ph_teacher_name"), text: $name)
                TextField(Loc.t("ph_teacher_email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                Button {
                    Task { await addTeacher() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("btn_add_teacher")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty || email.isEmpty)

                if let formError {
                    Text(formError).font(.footnote).foregroundStyle(.red)
                }
                if let credentialResult {
                    credentialResultBox(credentialResult, title: Loc.t("school_teacher_created_msg"))
                }
            }

            Section {
                if isLoading {
                    ProgressView()
                } else if teachers.isEmpty {
                    Text(Loc.t("school_no_teachers")).foregroundStyle(.secondary)
                } else {
                    ForEach(teachers) { teacher in
                        teacherRow(teacher)
                    }
                }
                if let resetResult {
                    credentialResultBox(resetResult, title: Loc.t("reset_password_result_msg"))
                }
                if let resetError {
                    Text(resetError).font(.footnote).foregroundStyle(.red)
                }
            }

            Section(Loc.t("broadcast_teachers_heading")) {
                TextField(Loc.t("ph_broadcast_body"), text: $broadcastBody, axis: .vertical)
                    .lineLimit(3...6)
                Button {
                    Task { await sendBroadcast() }
                } label: {
                    if isBroadcasting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("btn_send_broadcast")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isBroadcasting || broadcastBody.trimmingCharacters(in: .whitespaces).isEmpty)
                if let broadcastMessage {
                    Text(broadcastMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func teacherRow(_ teacher: TeacherSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(teacher.fullName?.isEmpty == false ? teacher.fullName! : teacher.username).font(.headline)
            if teacher.fullName?.isEmpty == false {
                Text(teacher.username).font(.caption).foregroundStyle(.secondary)
            }
            if !teacher.classes.isEmpty {
                Text(teacher.classes.map(\.name).joined(separator: "، ")).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("\(Loc.t("th_student_count")): \(teacher.studentCount)").font(.caption)
                Spacer()
                Text(teacher.lastLogin ?? Loc.t("never_logged_in")).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button(Loc.t("btn_reset_password")) {
                    teacherPendingReset = teacher
                }
                .font(.caption)
                Button(Loc.t("btn_delete"), role: .destructive) {
                    Task { await deleteTeacher(teacher) }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            Loc.t("confirm_reset_account_password"),
            isPresented: Binding(get: { teacherPendingReset?.id == teacher.id }, set: { if !$0 { teacherPendingReset = nil } }),
            titleVisibility: .visible
        ) {
            Button(Loc.t("btn_reset_password")) {
                Task { await resetPassword(teacher) }
            }
            Button(Loc.t("cancel"), role: .cancel) { teacherPendingReset = nil }
        }
    }

    private func load() async {
        isLoading = true
        teachers = (try? await APIClient.shared.schoolTeachers()) ?? []
        isLoading = false
    }

    private func addTeacher() async {
        formError = nil
        credentialResult = nil
        isSaving = true
        do {
            credentialResult = try await APIClient.shared.schoolAddTeacher(
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces)
            )
            name = ""
            email = ""
            await load()
        } catch {
            formError = Loc.t("error_generic")
        }
        isSaving = false
    }

    private func deleteTeacher(_ teacher: TeacherSummary) async {
        try? await APIClient.shared.schoolDeleteAccount(userId: teacher.userId)
        await load()
    }

    private func resetPassword(_ teacher: TeacherSummary) async {
        resetError = nil
        resetResult = nil
        do {
            resetResult = try await APIClient.shared.schoolResetAccountPassword(userId: teacher.userId)
        } catch {
            resetError = Loc.t("error_generic")
        }
    }

    private func sendBroadcast() async {
        isBroadcasting = true
        broadcastMessage = nil
        do {
            let count = try await APIClient.shared.schoolBroadcast(body: broadcastBody)
            broadcastMessage = String(format: Loc.t("broadcast_sent_msg"), count)
            broadcastBody = ""
        } catch {
            broadcastMessage = Loc.t("error_generic")
        }
        isBroadcasting = false
    }
}
