import SwiftUI

/// بوابة صلبة تظهر بدل أي شاشة ثانية لحساب مؤسسي (مدرسة/معلم/طالب مولّد
/// بالجملة) بكلمة سر مؤقتة - ما فيها أي طريق تخطّي (لا زر رجوع ولا إلغاء)،
/// تطابق سلوك موقع الويب بالضبط.
struct ForcePasswordChangeView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        newPassword.count >= 6 && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(Loc.t("force_pw_desc"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    SecureField(Loc.t("new_password"), text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField(Loc.t("confirm_password"), text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                if newPassword.count > 0, newPassword.count < 6 {
                    Text(Loc.t("err_password_min")).font(.footnote).foregroundStyle(.red)
                } else if !confirmPassword.isEmpty, newPassword != confirmPassword {
                    Text(Loc.t("err_password_mismatch")).font(.footnote).foregroundStyle(.red)
                }
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(Loc.t("save")).frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
            .navigationTitle(Loc.t("force_pw_heading"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await auth.updatePassword(newPassword)
            try await auth.completePasswordChange()
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isSaving = false
    }
}
