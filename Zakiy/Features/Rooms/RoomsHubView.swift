import SwiftUI

struct RoomsHubView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var invites: [SessionInvite] = []
    @State private var joinTarget: JoinTarget?

    private struct JoinTarget: Identifiable, Hashable {
        let roomCode: String
        let roomType: String
        var id: String { roomCode }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if auth.isAuthenticated, !invites.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Loc.t("session_invites")).font(.headline)
                        ForEach(invites) { invite in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(invite.fromUsername.map { String(format: Loc.t("invite_from"), $0) } ?? Loc.t("session_invites"))
                                        .font(.subheadline)
                                    Text(invite.roomCode).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(Loc.t("join")) {
                                    joinTarget = JoinTarget(roomCode: invite.roomCode, roomType: invite.roomType)
                                    Task { try? await APIClient.shared.dismissSessionInvite(id: invite.id) }
                                    invites.removeAll { $0.id == invite.id }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.accentColor)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding()
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                }

                // Each card leads into RoomLobbyView, which itself handles both creating a new
                // room of this type and joining an existing one by code — no separate join UI here.
                VStack(alignment: .leading, spacing: 12) {
                    Text(Loc.t("rooms")).font(.headline)

                    NavigationLink {
                        RoomLobbyView(roomType: "quiz")
                    } label: {
                        StudyOptionCard(icon: "person.3.fill", title: Loc.t("group_room"), subtitle: Loc.t("group_room_subtitle"))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        RoomLobbyView(roomType: "classroom")
                    } label: {
                        StudyOptionCard(icon: "person.crop.rectangle.stack.fill", title: Loc.t("room_type_classroom"), subtitle: Loc.t("live_lesson_subtitle"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("rooms"))
        .navigationDestination(item: $joinTarget) { target in
            RoomContainerView(roomCode: target.roomCode, roomType: target.roomType, isCreator: false)
        }
        .task { await loadInvites() }
        .refreshable { await loadInvites() }
    }

    private func loadInvites() async {
        guard auth.isAuthenticated else { return }
        invites = (try? await APIClient.shared.sessionInvites()) ?? []
    }
}
