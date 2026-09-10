import SwiftUI

struct MainTabView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(AppSettings.self) private var settings

    private enum TabID: Hashable {
        case home, rooms, schedule, library, performance, messages, settings
    }

    @State private var selectedTab: TabID = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(Loc.t("home"), systemImage: "house.fill", value: TabID.home) {
                NavigationStack { HomeView() }
            }
            Tab(Loc.t("rooms"), systemImage: "person.3.fill", value: TabID.rooms) {
                NavigationStack { RoomsHubView() }
            }
            // طالب مرتبط بمدرسة بس (role=student و class_id موجود) - حساب فردي
            // عادي ما يشوف هذا التبويب إطلاقًا
            if auth.role == "student", auth.classId != nil {
                Tab(Loc.t("my_schedule"), systemImage: "calendar", value: TabID.schedule) {
                    NavigationStack { StudentScheduleView() }
                }
            }
            Tab(Loc.t("library"), systemImage: "books.vertical.fill", value: TabID.library) {
                NavigationStack { LibraryListView() }
            }
            Tab(Loc.t("performance"), systemImage: "chart.line.uptrend.xyaxis", value: TabID.performance) {
                NavigationStack { PerformanceDashboardView() }
            }
            if auth.isAuthenticated {
                Tab(Loc.t("messages"), systemImage: "message.fill", value: TabID.messages) {
                    NavigationStack { MessagesView() }
                }
                .badge(NotificationSocketManager.shared.unreadCount)
            }
            Tab(Loc.t("settings"), systemImage: "gearshape.fill", value: TabID.settings) {
                NavigationStack { SettingsView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onAppear { consumeWidgetRouteIfNeeded() }
        .onChange(of: settings.pendingWidgetRoute) { _, _ in consumeWidgetRouteIfNeeded() }
    }

    private func consumeWidgetRouteIfNeeded() {
        guard settings.pendingWidgetRoute == "performance" else { return }
        selectedTab = .performance
        settings.pendingWidgetRoute = nil
    }
}
