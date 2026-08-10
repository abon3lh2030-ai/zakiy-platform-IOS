import SwiftUI

struct MainTabView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    var body: some View {
        TabView {
            Tab(Loc.t("home"), systemImage: "house.fill") {
                NavigationStack { HomeView() }
            }
            Tab(Loc.t("rooms"), systemImage: "person.3.fill") {
                NavigationStack { RoomsHubView() }
            }
            // طالب مرتبط بمدرسة بس (role=student و class_id موجود) - حساب فردي
            // عادي ما يشوف هذا التبويب إطلاقًا
            if auth.role == "student", auth.classId != nil {
                Tab(Loc.t("my_schedule"), systemImage: "calendar") {
                    NavigationStack { StudentScheduleView() }
                }
            }
            Tab(Loc.t("library"), systemImage: "books.vertical.fill") {
                NavigationStack { LibraryListView() }
            }
            Tab(Loc.t("performance"), systemImage: "chart.line.uptrend.xyaxis") {
                NavigationStack { PerformanceDashboardView() }
            }
            if auth.isAuthenticated {
                Tab(Loc.t("messages"), systemImage: "message.fill") {
                    NavigationStack { MessagesView() }
                }
                .badge(NotificationSocketManager.shared.unreadCount)
            }
            Tab(Loc.t("settings"), systemImage: "gearshape.fill") {
                NavigationStack { SettingsView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
