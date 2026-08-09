import SwiftUI

struct RoomsHubView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var invites: [SessionInvite] = []
    @State private var joinCode = ""
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

                VStack(alignment: .leading, spacing: 12) {
                    Text(Loc.t("create_room")).font(.headline)

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

                VStack(alignment: .leading, spacing: 12) {
                    Text(Loc.t("join_by_code")).font(.headline)
                    HStack(spacing: 10) {
                        TextField(Loc.t("room_code_placeholder"), text: $joinCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Button(Loc.t("join")) {
                            let code = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
                            guard !code.isEmpty else { return }
                            joinTarget = JoinTarget(roomCode: code, roomType: "quiz")
                        }
                        .buttonStyle(.appPrimary)
                        .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
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
