import SwiftUI

struct SignUpView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var educationLevel = ""
    @State private var proficiencyLevel = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Loc.t("username"), text: $username)
                        .accessibilityIdentifier("signup_username_field")
                    TextField(Loc.t("email"), text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .accessibilityIdentifier("signup_email_field")
                    SecureField(Loc.t("password"), text: $password)
                        .textContentType(.newPassword)
                        .accessibilityIdentifier("signup_password_field")
                    TextField(Loc.t("education_level"), text: $educationLevel)
                        .accessibilityIdentifier("signup_education_level_field")
                    TextField(Loc.t("proficiency_level"), text: $proficiencyLevel)
                        .accessibilityIdentifier("signup_proficiency_level_field")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                        .accessibilityIdentifier("signup_error_message")
                }
                Section {
                    Button {
                        Task { await signUp() }
                    } label: {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(Loc.t("signup")).frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty || username.isEmpty)
                    .accessibilityIdentifier("signup_submit_button")
                }
            }
            .navigationTitle(Loc.t("signup"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("cancel")) { dismiss() }
                }
            }
        }
    }

    private func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await auth.signUp(email: email, password: password, username: username, educationLevel: educationLevel, proficiencyLevel: proficiencyLevel)
            dismiss()
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isLoading = false
    }
}
