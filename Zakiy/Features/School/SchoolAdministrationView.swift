import SwiftUI

/// حسابات "إداري المدرسة" (school_administration) - نفس صلاحيات مدير
/// المدرسة على المعلمين/الطلاب/الحضور، إلا إدارة حساب مدير/إداري ثاني.
/// إضافة/حذف إداري محجوزة على مدير المدرسة (school_admin) نفسه فقط - نفس
/// القيد المطبّق أصلًا بالباك إند - إداري ثاني يشوف القائمة بس.
struct SchoolAdministrationView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var staff: [AdminStaffSummary] = []
    @State private var isLoading = true

    @State private var name = ""
    @State private var email = ""
    @State private var isSaving = false
    @State private var formError: String?
    @State private var credentialResult: GeneratedCredentials?

    @State private var resetResult: AccountResetCredentials?
    @State private var resetError: String?
    @State private var staffPendingReset: AdminStaffSummary?

    private var canManage: Bool { auth.role == "school_admin" }

    var body: some View {
        List {
            if canManage {
                Section(Loc.t("btn_add_admin_staff")) {
                    TextField(Loc.t("ph_admin_staff_name"), text: $name)
                    TextField(Loc.t("ph_admin_staff_email"), text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                    Button {
                        Task { await addStaff() }
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(Loc.t("btn_add_admin_staff")).frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty || email.isEmpty)

                    if let formError {
                        Text(formError).font(.footnote).foregroundStyle(.red)
                    }
                    if let credentialResult {
                        credentialResultBox(credentialResult, title: Loc.t("school_admin_staff_created_msg"))
                    }
                }
            }

            Section {
                if isLoading {
                    ProgressView()
                } else if staff.isEmpty {
                    Text(Loc.t("school_no_admin_staff")).foregroundStyle(.secondary)
                } else {
                    ForEach(staff) { member in
                        staffRow(member)
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
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(Loc.t("admin_staff_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func staffRow(_ member: AdminStaffSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(member.username).font(.headline)
            Text(member.lastLogin ?? Loc.t("never_logged_in")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(Loc.t("btn_reset_password")) {
                    staffPendingReset = member
                }
                .font(.caption)
                if canManage {
                    Button(Loc.t("btn_delete"), role: .destructive) {
                        Task { await deleteStaff(member) }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            Loc.t("confirm_reset_account_password"),
            isPresented: Binding(get: { staffPendingReset?.id == member.id }, set: { if !$0 { staffPendingReset = nil } }),
            titleVisibility: .visible
        ) {
            Button(Loc.t("btn_reset_password")) {
                Task { await resetPassword(member) }
            }
            Button(Loc.t("cancel"), role: .cancel) { staffPendingReset = nil }
        }
    }

    private func load() async {
        isLoading = true
        staff = (try? await APIClient.shared.schoolAdministrationStaff()) ?? []
        isLoading = false
    }

    private func addStaff() async {
        formError = nil
        credentialResult = nil
        isSaving = true
        do {
            credentialResult = try await APIClient.shared.schoolAddAdministration(
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

    private func deleteStaff(_ member: AdminStaffSummary) async {
        try? await APIClient.shared.schoolDeleteAccount(userId: member.userId)
        await load()
    }

    private func resetPassword(_ member: AdminStaffSummary) async {
        resetError = nil
        resetResult = nil
        do {
            resetResult = try await APIClient.shared.schoolResetAccountPassword(userId: member.userId)
        } catch {
            resetError = Loc.t("error_generic")
        }
    }
}
