import SwiftUI

/// لوحة الأدمن العام: إنشاء مدرسة (وحساب مديرها) + قائمة كل المدارس مع
/// تفعيل/إيقاف وإعادة تعيين كلمة سر مدير أي مدرسة.
struct AdminDashboardView: View {
    @State private var schools: [School] = []
    @State private var isLoading = true

    @State private var newSchoolName = ""
    @State private var newSchoolAdminEmail = ""
    @State private var newSchoolMaxAccounts = ""
    @State private var isCreating = false
    @State private var formError: String?
    @State private var credentialResult: GeneratedCredentials?
    @State private var actionError: String?

    var body: some View {
        List {
            Section(Loc.t("admin_add_school_heading")) {
                TextField(Loc.t("ph_school_name"), text: $newSchoolName)
                TextField(Loc.t("ph_school_admin_email"), text: $newSchoolAdminEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                TextField(Loc.t("ph_max_accounts"), text: $newSchoolMaxAccounts)
                    .keyboardType(.numberPad)

                Button {
                    Task { await createSchool() }
                } label: {
                    if isCreating {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("btn_create_school")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isCreating || newSchoolName.trimmingCharacters(in: .whitespaces).isEmpty || newSchoolAdminEmail.isEmpty)

                if let formError {
                    Text(formError).font(.footnote).foregroundStyle(.red)
                }
                if let credentialResult {
                    credentialBox(credentialResult, title: Loc.t("admin_password_reset_msg"))
                }
            }

            Section(Loc.t("admin_schools_list_heading")) {
                if isLoading {
                    ProgressView()
                } else if schools.isEmpty {
                    Text(Loc.t("admin_no_schools")).foregroundStyle(.secondary)
                } else {
                    ForEach(schools) { school in
                        schoolRow(school)
                    }
                }
                if let actionError {
                    Text(actionError).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(Loc.t("admin_dash_heading"))
        .toolbar { RoleDashboardToolbar() }
        .task { await load() }
        .refreshable { await load() }
    }

    private func credentialBox(_ creds: GeneratedCredentials, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote.bold())
            Text(creds.email).font(.footnote)
            Text(creds.password).font(.footnote.monospaced())
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func schoolRow(_ school: School) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(school.name).font(.headline)
            if let email = school.adminEmail {
                Text(email).font(.caption).foregroundStyle(.secondary)
            }
            Text("\(school.accountsUsed ?? 0) / \(school.maxAccounts)")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(school.isActive ? Loc.t("status_active") : Loc.t("status_inactive"))
                    .font(.caption.bold())
                    .foregroundStyle(school.isActive ? .green : .red)
                Spacer()
                Button(school.isActive ? Loc.t("btn_deactivate") : Loc.t("btn_activate")) {
                    Task { await toggleActive(school) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button(Loc.t("btn_reset_password")) {
                    Task { await resetPassword(school) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true
        schools = (try? await APIClient.shared.adminSchools()) ?? []
        isLoading = false
    }

    private func createSchool() async {
        formError = nil
        credentialResult = nil
        isCreating = true
        let maxAccounts = Int(newSchoolMaxAccounts) ?? 0
        do {
            let response = try await APIClient.shared.adminCreateSchool(
                name: newSchoolName.trimmingCharacters(in: .whitespaces),
                adminEmail: newSchoolAdminEmail.trimmingCharacters(in: .whitespaces),
                maxAccounts: maxAccounts
            )
            credentialResult = response.schoolAdmin
            newSchoolName = ""
            newSchoolAdminEmail = ""
            newSchoolMaxAccounts = ""
            await load()
        } catch {
            formError = Loc.t("error_generic")
        }
        isCreating = false
    }

    private func toggleActive(_ school: School) async {
        actionError = nil
        do {
            try await APIClient.shared.adminSetSchoolActive(id: school.id, isActive: !school.isActive)
            await load()
        } catch {
            actionError = Loc.t("error_generic")
        }
    }

    private func resetPassword(_ school: School) async {
        actionError = nil
        do {
            credentialResult = try await APIClient.shared.adminResetSchoolAdminPassword(schoolId: school.id)
        } catch {
            actionError = Loc.t("error_generic")
        }
    }
}
