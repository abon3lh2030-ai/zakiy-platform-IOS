import SwiftUI

/// صف قائمة موحّد لكل لوحات الأدوار المؤسسية (معلم/مدرسة/أدمن) - أيقونة
/// ملوّنة + عنوان، بنفس أسلوب شاشة الإعدادات (SettingsView) بالضبط عشان
/// التنقّل يحس متسق بكل التطبيق. يُستخدم كتسمية NavigationLink داخل List،
/// مو Button مستقل - القائمة اللي تحوطه هي اللي تسوي التنقّل الفعلي.
struct DashboardMenuRow: View {
    let icon: String
    var tint: Color = .accentColor
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8))
            Text(title).font(.body)
        }
        .padding(.vertical, 2)
    }
}
