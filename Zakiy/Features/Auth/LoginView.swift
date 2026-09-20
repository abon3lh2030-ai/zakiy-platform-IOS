import SwiftUI

struct LoginView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var identifier = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPassword = false
    @State private var isResetFormVisible = false
    @State private var resetEmail = ""
    @State private var resetMessage: String?
    @State private var isSendingReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // حسابات مؤسسية (طلاب مولّدين بالجملة) تسجّل دخول باسم
                    // مستخدم بدون إيميل حقيقي - نفس حقل الإيميل يقبل الاثنين
                    TextField(Loc.t("email_or_username"), text: $identifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("login_identifier_field")
                    PasswordEntryField(
                        title: Loc.t("password"),
                        text: $password,
                        accessibilityIdentifier: "login_password_field"
                    )
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                        .accessibilityIdentifier("login_error_message")
                }
                if showForgotPassword {
                    Section {
                        Button(Loc.t("forgot_password")) {
                            resetEmail = identifier.contains("@") ? identifier : ""
                            resetMessage = nil
                            isResetFormVisible = true
                        }
                        if isResetFormVisible {
                            TextField(Loc.t("email"), text: $resetEmail)
                                .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                            Button(Loc.t("send_reset_link")) { Task { await sendResetLink() } }
                                .disabled(isSendingReset || !resetEmail.contains("@"))
                            if let resetMessage { Text(resetMessage).font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
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
                    .accessibilityIdentifier("login_submit_button")
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
            showForgotPassword = true
        }
        isLoading = false
    }

    private func sendResetLink() async {
        isSendingReset = true
        do {
            try await auth.requestPasswordReset(email: resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            resetMessage = Loc.t("reset_link_sent")
        } catch {
            resetMessage = error.localizedDescription
        }
        isSendingReset = false
    }
}
