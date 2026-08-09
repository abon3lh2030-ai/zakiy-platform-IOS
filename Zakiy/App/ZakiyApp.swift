import SwiftUI

@main
struct ZakiyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppSettings.shared)
                .environment(SupabaseAuthManager.shared)
        }
    }
}
