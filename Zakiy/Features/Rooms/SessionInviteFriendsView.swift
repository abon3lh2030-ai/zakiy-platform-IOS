import SwiftUI

/// Friend picker used from `RoomInviteView` to send a direct session invite (rather than
/// sharing the raw room code) to one or more friends.
struct SessionInviteFriendsView: View {
    let roomCode: String
    let roomType: String

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [Friend] = []
    @State private var isLoading = true
    @State private var sentTo: Set<String> = []
    @State private var sendingTo: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if friends.isEmpty {
                ContentUnavailableView(Loc.t("friends"), systemImage: "person.2", description: Text(Loc.t("no_friends_yet")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(friends) { friend in
                    HStack {
                        Text(friend.username)
                        Spacer()
                        if sentTo.contains(friend.userId) {
                            Label(Loc.t("invited"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.accentColor)
                                .labelStyle(.iconOnly)
                        } else if sendingTo == friend.userId {
                            ProgressView().controlSize(.small)
                        } else {
                            Button(Loc.t("invite")) {
                                Task { await invite(friend) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("invite_friends"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        friends = (try? await APIClient.shared.friends()) ?? []
        isLoading = false
    }

    private func invite(_ friend: Friend) async {
        sendingTo = friend.userId
        try? await APIClient.shared.sendSessionInvite(toUserId: friend.userId, roomCode: roomCode, roomType: roomType)
        sentTo.insert(friend.userId)
        sendingTo = nil
    }
}
