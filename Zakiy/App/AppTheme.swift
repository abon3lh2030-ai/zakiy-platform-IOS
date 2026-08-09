import SwiftUI

/// هوية الألوان الأساسية للتطبيق - نفس ألوان الشعار وموقع الويب بالضبط:
/// بيج فاتح/كحلي غامق للخلفية حسب الوضع، وذهبي/أصفر ثابت كلون أساسي للأزرار
/// بالوضعين، مع نص متباين (كحلي باللايت، بيج بالدارك) فوقه.
struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.appAccentText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 20)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension ButtonStyle where Self == AppPrimaryButtonStyle {
    static var appPrimary: AppPrimaryButtonStyle { AppPrimaryButtonStyle() }
}
