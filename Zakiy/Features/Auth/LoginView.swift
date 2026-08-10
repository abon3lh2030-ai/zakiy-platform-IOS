import SwiftUI

struct LoginView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var identifier = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // حسابات مؤسسية (طلاب مولّدين بالجملة) تسجّل دخول باسم
                    // مستخدم بدون إيميل حقيقي - نفس حقل الإيميل يقبل الاثنين
                    TextField(Loc.t("email_or_username"), text: $identifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
                    .disabled(isLoading || identifier.isEmpty || password.isEmpty)
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
            try await auth.signInWithIdentifier(identifier, password: password)
            dismiss()
        } catch {
            errorMessage = Loc.t("err_wrong_credentials")
        }
        isLoading = false
    }
}
