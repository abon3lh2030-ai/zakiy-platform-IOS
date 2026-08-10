import SwiftUI

/// أزرار مشتركة بأعلى كل لوحة دور مؤسسي (أدمن/مدرسة/معلم) - الرسائل (بشارة
/// عدد غير مقروء) وتسجيل الخروج. هاللوحات تحل محل MainTabView بالكامل، فما
/// عندها وصول للتبويبات العادية - هذا هو الطريق الوحيد للرسائل بالنسبة لها.
struct RoleDashboardToolbar: ToolbarContent {
    @Environment(SupabaseAuthManager.self) private var auth

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                MessagesView()
            } label: {
                Image(systemName: NotificationSocketManager.shared.unreadCount > 0 ? "message.badge.fill" : "message")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(Loc.t("logout")) { Task { try? await auth.signOut() } }
        }
    }
}
