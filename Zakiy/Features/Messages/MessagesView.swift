import SwiftUI

/// شاشة الرسائل والتنبيهات - محادثات ثنائية مع أي مستخدم بالتطبيق (بدون قيد
/// صداقة) + تنبيهات (رسالة جديدة/بث جماعي/تذكير حصة/بدء حصة).
struct MessagesView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case conversations, notifications
        var id: String { rawValue }
        var titleKey: String { self == .conversations ? "tab_conversations" : "tab_notifications" }
    }

    @State private var tab: Tab = .conversations

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(Loc.t(t.titleKey)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch tab {
                case .conversations: ConversationsListView()
                case .notifications: NotificationsListView()
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("messages_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await NotificationSocketManager.shared.refreshUnreadCount() }
    }
}
