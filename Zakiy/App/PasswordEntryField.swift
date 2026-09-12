import SwiftUI

/// حقل كلمة مرور موحّد مع زر إظهار/إخفاء، ويحتفظ بنفس القيمة عند تبديل نوع الحقل.
struct PasswordEntryField: View {
    let title: String
    @Binding var text: String
    var isNewPassword = false
    let accessibilityIdentifier: String

    @State private var isVisible = false

    var body: some View {
        HStack {
            if isVisible {
                TextField(title, text: $text)
                    .textContentType(isNewPassword ? .newPassword : .password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier(accessibilityIdentifier)
            } else {
                SecureField(title, text: $text)
                    .textContentType(isNewPassword ? .newPassword : .password)
                    .accessibilityIdentifier(accessibilityIdentifier)
            }

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Loc.t(isVisible ? "hide_password" : "show_password"))
            .accessibilityIdentifier("\(accessibilityIdentifier)_visibility_toggle")
        }
    }
}
