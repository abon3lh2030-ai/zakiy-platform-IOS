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
                    TextField(Loc.t("email"), text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField(Loc.t("password"), text: $password)
                    TextField(Loc.t("education_level"), text: $educationLevel)
                    TextField(Loc.t("proficiency_level"), text: $proficiencyLevel)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
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
