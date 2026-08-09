import SwiftUI

struct EditProfileView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var username = ""
    @State private var phone = ""
    @State private var newPassword = ""
    @State private var isSavingProfile = false
    @State private var isSavingPassword = false
    @State private var profileMessage: String?
    @State private var passwordMessage: String?

    var body: some View {
        Form {
            Section(Loc.t("username")) {
                TextField(Loc.t("username"), text: $username)
                TextField(Loc.t("phone_number"), text: $phone)
                    .keyboardType(.phonePad)

                Button {
                    Task { await saveProfile() }
                } label: {
                    if isSavingProfile {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("save")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSavingProfile || username.trimmingCharacters(in: .whitespaces).isEmpty)

                if let profileMessage {
                    Text(profileMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section(Loc.t("password")) {
                SecureField(Loc.t("new_password"), text: $newPassword)
                    .textContentType(.newPassword)

                Button {
                    Task { await savePassword() }
                } label: {
                    if isSavingPassword {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("update_password")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSavingPassword || newPassword.count < 6)

                if let passwordMessage {
                    Text(passwordMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(Loc.t("edit_profile"))
        .onAppear {
            username = auth.username
            phone = auth.phone
        }
    }

    private func saveProfile() async {
        isSavingProfile = true
        profileMessage = nil
        do {
            try await auth.updateProfile(username: username, phone: phone)
            profileMessage = Loc.t("profile_updated")
        } catch {
            profileMessage = Loc.t("error_generic")
        }
        isSavingProfile = false
    }

    private func savePassword() async {
        isSavingPassword = true
        passwordMessage = nil
        do {
            try await auth.updatePassword(newPassword)
            newPassword = ""
            passwordMessage = Loc.t("password_updated")
        } catch {
            passwordMessage = Loc.t("error_generic")
        }
        isSavingPassword = false
    }
}
