import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab(Loc.t("home"), systemImage: "house.fill") {
                NavigationStack { HomeView() }
            }
            Tab(Loc.t("rooms"), systemImage: "person.3.fill") {
                NavigationStack { RoomsHubView() }
            }
            Tab(Loc.t("library"), systemImage: "books.vertical.fill") {
                NavigationStack { LibraryListView() }
            }
            Tab(Loc.t("performance"), systemImage: "chart.line.uptrend.xyaxis") {
                NavigationStack { PerformanceDashboardView() }
            }
            Tab(Loc.t("settings"), systemImage: "gearshape.fill") {
                NavigationStack { SettingsView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
