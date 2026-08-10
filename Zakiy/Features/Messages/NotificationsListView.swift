import SwiftUI

struct NotificationsListView: View {
    private struct JoinDestination: Identifiable, Hashable {
        let roomCode: String
        var id: String { roomCode }
    }

    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = true
    @State private var joinDestination: JoinDestination?

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
                        // دعوة انضمام فورية للطالب - المعلم بدأ درسه المباشر
                        // فعليًا وهذا التنبيه معه كود الغرفة جاهز، يدخل بضغطة
                        // وحدة بدون ما يكتب الكود يدويًا
                        if item.type == "class_started", let code = item.relatedRoomCode {
                            Button(Loc.t("btn_join_class_now")) { joinDestination = JoinDestination(roomCode: code) }
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(item: $joinDestination) { dest in
            RoomContainerView(roomCode: dest.roomCode, roomType: "classroom", isCreator: false, guestName: auth.username)
        }
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
