import SwiftUI

@main
struct ZakiyApp: App {
    init() {
        // أُلغي وضع الضيف نهائيًا؛ نمسح أي اختيار قديم محفوظ من نسخ سابقة
        // حتى يرجع المستخدم غير المسجّل مباشرة لشاشة الدخول/إنشاء الحساب.
        UserDefaults.standard.removeObject(forKey: "zakiy.isGuest")
        UserDefaults.standard.removeObject(forKey: "zakiy.guestName")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppSettings.shared)
                .environment(SupabaseAuthManager.shared)
        }
    }
}
