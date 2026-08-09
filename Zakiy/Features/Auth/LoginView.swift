import SwiftUI

struct LoginView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Loc.t("email"), text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField(Loc.t("password"), text: $password)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(Loc.t("login")).frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle(Loc.t("login"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("cancel")) { dismiss() }
                }
            }
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await auth.signIn(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isLoading = false
    }
}
