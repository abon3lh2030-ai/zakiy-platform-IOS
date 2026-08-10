import SwiftUI

struct NotificationsListView: View {
    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if notifications.isEmpty {
                Text(Loc.t("no_notifications_yet")).foregroundStyle(.secondary)
            } else {
                ForEach(notifications) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(icon(for: item.type)) \(item.title)").font(.subheadline.bold())
                        if let body = item.body {
                            Text(body).font(.caption).foregroundStyle(.secondary)
                        }
                        // زر سريع للمعلم بس - يرجعه للوحته (اللي أصلًا تحت هذي
                        // الشاشة بنفس مكدّس التنقّل) عشان يختار الفصل ويبدأ
                        if item.type == "schedule_reminder", auth.role == "teacher" {
                            Button(Loc.t("btn_start_now")) { dismiss() }
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func icon(for type: String) -> String {
        switch type {
        case "new_message": "💬"
        case "broadcast": "📢"
        case "schedule_reminder": "⏰"
        case "class_started": "🖍️"
        default: "🔔"
        }
    }

    private func load() async {
        isLoading = true
        if let data = try? await APIClient.shared.notifications() {
            notifications = data.notifications
        }
        try? await APIClient.shared.markNotificationsRead()
        await NotificationSocketManager.shared.refreshUnreadCount()
        isLoading = false
    }
}
