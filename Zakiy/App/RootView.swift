import SwiftUI

struct RootView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if auth.isBootstrapping {
                SplashView()
            } else if auth.isAuthenticated || settings.isGuest {
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
        .environment(\.locale, settings.locale)
        .environment(\.layoutDirection, settings.layoutDirection)
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .id(settings.languageCode)
        .task(id: auth.isAuthenticated) {
            guard auth.isAuthenticated else { return }
            try? await APIClient.shared.pingActive()
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
