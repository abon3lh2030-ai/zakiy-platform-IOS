import SwiftUI

/// Owns the socket connection for the lifetime of a room visit, and routes to the right
/// room-type screen once the server confirms the room state.
struct RoomContainerView: View {
    let roomCode: String
    let roomType: String
    let isCreator: Bool
    var guestName: String?

    @Environment(SupabaseAuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var socket = RoomSocketManager()
    @State private var hasConnected = false

    private var displayName: String {
        if auth.isAuthenticated { return auth.username }
        if let guestName, !guestName.trimmingCharacters(in: .whitespaces).isEmpty { return guestName }
        if !AppSettings.shared.guestName.isEmpty { return AppSettings.shared.guestName }
        return Loc.t("default_student_name")
    }

    var body: some View {
        Group {
            if socket.wasKicked {
                ContentUnavailableView(Loc.t("kicked_from_room"), systemImage: "xmark.octagon", description: Text(Loc.t("kicked_from_room_desc")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = socket.errorMessage {
                ContentUnavailableView(Loc.t("error_generic"), systemImage: "wifi.exclamationmark", description: Text(error))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !socket.isConnected || socket.roomState.roomCode.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                    Text(Loc.t("connecting_to_room")).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if socket.roomState.roomType == "classroom" {
                ClassroomView(socket: socket)
            } else {
                RoomQuizView(socket: socket)
            }
        }
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(roomType == "classroom" ? Loc.t("room_type_classroom") : Loc.t("group_room")).font(.subheadline.bold())
                    Text(roomCode).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            guard !hasConnected else { return }
            hasConnected = true
            socket.connect(roomCode: roomCode, name: displayName)
        }
        .onDisappear { socket.disconnect() }
        .onChange(of: socket.wasKicked) { _, kicked in
            if kicked { dismiss() }
        }
    }
}
