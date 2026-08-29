import SwiftUI

@main
struct ZakiyApp: App {
    init() {
        // اختبارات الواجهة (XCUITest) تمرّر هذا العلم عشان كل تشغيل يبدأ من
        // شاشة الترحيب دايمًا - نمسح فقط تفضيلات وضع الضيف المحفوظة محليًا
        // (الجلسة نفسها معزولة أصلًا بالذاكرة عبر InMemoryAuthLocalStorage
        // بـ SupabaseAuthManager) - العلم ما يُمرَّر أبدًا بالاستخدام العادي.
        if ProcessInfo.processInfo.arguments.contains("-UITestResetState") {
            UserDefaults.standard.removeObject(forKey: "zakiy.isGuest")
            UserDefaults.standard.removeObject(forKey: "zakiy.guestName")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppSettings.shared)
                .environment(SupabaseAuthManager.shared)
        }
    }
}
