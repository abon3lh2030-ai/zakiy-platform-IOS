import SwiftUI

/// Host-only sheet for managing participants: grant/revoke content permissions, force-mute,
/// kick, and trigger a lucky draw.
struct RoomManagementPanel: View {
    @Bindable var socket: RoomSocketManager
    @Environment(\.dismiss) private var dismiss
    @State private var kickTarget: RoomParticipant?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        socket.luckyDraw()
                    } label: {
                        Label(Loc.t("lucky_draw"), systemImage: "dice.fill")
                    }
                }

                Section(Loc.t("participants")) {
                    ForEach(socket.leaderboard) { participant in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(participant.name).font(.subheadline.bold())
                                if participant.isCoHost {
                                    Text(Loc.t("co_host_badge")).font(.caption2).foregroundStyle(Color.accentColor)
                                }
                            }

                            HStack(spacing: 10) {
                                Button {
                                    if participant.isCoHost {
                                        socket.revokePermission(sid: participant.sid)
                                    } else {
                                        socket.grantPermission(sid: participant.sid)
                                    }
                                } label: {
                                    Text(participant.isCoHost ? Loc.t("revoke_permission") : Loc.t("grant_permission"))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button {
                                    socket.forceMute(sid: participant.sid)
                                } label: {
                                    Label(Loc.t("mute"), systemImage: "mic.slash.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button(role: .destructive) {
                                    kickTarget = participant
                                } label: {
                                    Label(Loc.t("kick"), systemImage: "person.fill.xmark")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(Loc.t("room_management"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("close")) { dismiss() }
                }
            }
            .alert(Loc.t("confirm_kick"), isPresented: .constant(kickTarget != nil)) {
                Button(Loc.t("cancel"), role: .cancel) { kickTarget = nil }
                Button(Loc.t("kick"), role: .destructive) {
                    if let kickTarget { socket.kickParticipant(sid: kickTarget.sid) }
                    kickTarget = nil
                }
            }
        }
    }
}
