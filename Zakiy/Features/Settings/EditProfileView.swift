import SwiftUI

struct EditProfileView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var username = ""
    @State private var phone = ""
    @State private var newPassword = ""
    @State private var currentPassword = ""
    @State private var confirmPassword = ""
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
                PasswordEntryField(title: Loc.t("current_password"), text: $currentPassword, accessibilityIdentifier: "settings_current_password_field")
                PasswordEntryField(
                    title: Loc.t("new_password"),
                    text: $newPassword,
                    isNewPassword: true,
                    accessibilityIdentifier: "settings_new_password_field"
                )
                PasswordEntryField(title: Loc.t("confirm_password"), text: $confirmPassword, isNewPassword: true, accessibilityIdentifier: "settings_confirm_password_field")

                Button {
                    Task { await savePassword() }
                } label: {
                    if isSavingPassword {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("update_password")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSavingPassword || currentPassword.isEmpty || newPassword.count < 6 || newPassword != confirmPassword)

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
            try await auth.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            passwordMessage = Loc.t("password_updated")
        } catch {
            passwordMessage = Loc.t("current_password_wrong")
        }
        isSavingPassword = false
    }
}
