import SwiftUI

struct RootView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if auth.isBootstrapping || (auth.isAuthenticated && !auth.didLoadRole) {
                SplashView()
            } else if auth.isAuthenticated && auth.mustChangePassword {
                // بوابة صلبة - حساب مؤسسي بكلمة سر مؤقتة لازم يغيّرها قبل أي
                // شي ثاني، بدون أي طريق تخطّي (نفس مبدأ موقع الويب بالضبط)
                ForcePasswordChangeView()
                    .transition(.opacity)
            } else if auth.isAuthenticated, let role = auth.role, let accountRole = AccountRole(rawValue: role) {
                RoleRoutedView(role: accountRole)
                    .transition(.opacity)
            } else if auth.isAuthenticated || settings.isGuest {
                // حساب فردي عادي (role == nil) أو ضيف - نفس تجربة التطبيق
                // الحالية بدون أي تغيير
                MainTabView()
                    .transition(.opacity)
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: auth.isAuthenticated)
        .animation(.default, value: settings.isGuest)
        .animation(.default, value: auth.isBootstrapping)
        .animation(.default, value: auth.didLoadRole)
        .animation(.default, value: auth.mustChangePassword)
        .animation(.default, value: auth.role)
        .environment(\.locale, settings.locale)
        .environment(\.layoutDirection, settings.layoutDirection)
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .id(settings.languageCode)
        .task(id: auth.isAuthenticated) {
            guard auth.isAuthenticated else {
                NotificationSocketManager.shared.disconnect()
                return
            }
            try? await APIClient.shared.pingActive()
            NotificationSocketManager.shared.connectIfNeeded()
            await NotificationSocketManager.shared.refreshUnreadCount()
        }
    }
}

/// يوجّه لللوحة المناسبة حسب الدور - كل الأدوار المؤسسية الخمسة، بدون ما
/// يلمس مسار الحساب الفردي العادي (`role == nil`) إطلاقًا.
private struct RoleRoutedView: View {
    let role: AccountRole

    var body: some View {
        switch role {
        case .admin:
            NavigationStack { AdminDashboardView() }
        case .schoolAdmin, .schoolAdministration:
            NavigationStack { SchoolDashboardView() }
        case .teacher:
            NavigationStack { TeacherDashboardView() }
        case .student:
            MainTabView()
        }
    }
}

private struct SplashView: View {
    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 220)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
    }
}
