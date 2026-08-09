import SwiftUI

struct RoomInviteView: View {
    let roomCode: String
    let roomType: String

    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseAuthManager.self) private var auth

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(Loc.t("room_code")).font(.caption).foregroundStyle(.secondary)
                    Text(roomCode)
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .kerning(4)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))

                ShareLink(item: Loc.t("share_room_invite_text") + " " + roomCode) {
                    Label(Loc.t("share_room_code"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if auth.isAuthenticated {
                    NavigationLink {
                        SessionInviteFriendsView(roomCode: roomCode, roomType: roomType)
                    } label: {
                        Label(Loc.t("invite_friends"), systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.appPrimary)
                }

                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle(Loc.t("invite_to_room"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("close")) { dismiss() }
                }
            }
        }
    }
}
