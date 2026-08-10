import SwiftUI

struct FriendsListView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var friends: [Friend] = []
    @State private var incomingRequests: [FriendRequest] = []
    @State private var sessionInvites: [SessionInvite] = []
    @State private var isLoading = true
    @State private var showMyQR = false
    @State private var showScanner = false
    @State private var searchText = ""
    @State private var searchResults: [Friend] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var joinTarget: JoinTarget?
    @State private var removeTarget: Friend?

    private struct JoinTarget: Identifiable, Hashable {
        let roomCode: String
        let roomType: String
        var id: String { roomCode }
    }

    var body: some View {
        Group {
            if !auth.isAuthenticated {
                ContentUnavailableView(Loc.t("friends"), systemImage: "person.2", description: Text(Loc.t("friends_guest_gate")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        qrCard

                        sectionBlock(title: Loc.t("session_invites"), icon: "envelope.badge.fill") {
                            if sessionInvites.isEmpty {
                                Text(Loc.t("session_invites_empty")).foregroundStyle(.secondary).padding(.vertical, 4)
                            } else {
                                ForEach(sessionInvites) { invite in
                                    // .frame(maxWidth: .infinity) on every row below — without it,
                                    // an HStack only sizes to fit its own content, so inside the
                                    // section's leading-aligned VStack it hugs the right (leading)
                                    // edge and the Spacer never gets real room to push the trailing
                                    // button out to the card's actual left edge.
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(invite.fromUsername.map { String(format: Loc.t("invite_from"), $0) } ?? Loc.t("session_invites"))
                                            Text(invite.roomCode).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button(Loc.t("join")) {
                                            joinTarget = JoinTarget(roomCode: invite.roomCode, roomType: invite.roomType)
                                            sessionInvites.removeAll { $0.id == invite.id }
                                            Task { try? await APIClient.shared.dismissSessionInvite(id: invite.id) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.accentColor)
                                        .controlSize(.small)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    if invite.id != sessionInvites.last?.id { Divider() }
                                }
                            }
                        }

                        if !incomingRequests.isEmpty {
                            sectionBlock(title: Loc.t("friend_requests"), icon: "person.badge.clock.fill") {
                                ForEach(incomingRequests) { req in
                                    HStack {
                                        Text(req.username)
                                        Spacer()
                                        Button(Loc.t("accept")) {
                                            Task { await respond(req, accept: true) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.accentColor)
                                        .controlSize(.small)
                                        Button(Loc.t("decline")) {
                                            Task { await respond(req, accept: false) }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    if req.id != incomingRequests.last?.id { Divider() }
                                }
                            }
                        }

                        sectionBlock(title: Loc.t("my_friends"), icon: "person.2.fill") {
                            if friends.isEmpty {
                                Text(Loc.t("no_friends_yet")).foregroundStyle(.secondary).padding(.vertical, 4)
                            } else {
                                ForEach(friends) { friend in
                                    HStack(alignment: .center) {
                                        // .foregroundStyle(.primary) has to sit on the
                                        // NavigationLink itself, not on the Text inside its
                                        // label — set on the inner Text, the link's own tint
                                        // silently overrides it and the name renders gold anyway.
                                        NavigationLink {
                                            ProfileView(userId: friend.userId)
                                        } label: {
                                            Text(friend.username)
                                        }
                                        .foregroundStyle(.primary)
                                        Spacer()
                                        // A hand-sized pill, not .buttonStyle(.bordered) — the
                                        // system bordered style carries its own large minimum tap
                                        // padding that made the pill visibly bigger than the name
                                        // text next to it no matter how the row was aligned.
                                        Button(role: .destructive) {
                                            removeTarget = friend
                                        } label: {
                                            Text(Loc.t("delete"))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.red)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.red.opacity(0.15), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    if friend.id != friends.last?.id { Divider() }
                                }
                            }
                        }

                        sectionBlock(title: Loc.t("add_friend_section"), icon: "person.badge.plus") {
                            HStack {
                                TextField(Loc.t("search_by_username"), text: $searchText)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onSubmit { Task { await search() } }
                                Button(Loc.t("search")) { Task { await search() } }
                                    .buttonStyle(.bordered)
                                    .tint(Color.appLinkText)
                                    .controlSize(.small)
                            }

                            if isSearching {
                                ProgressView().padding(.top, 6)
                            } else if !searchResults.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(searchResults) { user in
                                        HStack {
                                            Text(user.username)
                                            Spacer()
                                            Button(Loc.t("add_friend")) {
                                                Task { await sendRequest(to: user) }
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(Color.appLinkText)
                                            .controlSize(.small)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("friends"))
        .sheet(isPresented: $showMyQR) { MyQRCodeView() }
        .sheet(isPresented: $showScanner) { QRScannerView() }
        .navigationDestination(item: $joinTarget) { target in
            RoomContainerView(roomCode: target.roomCode, roomType: target.roomType, isCreator: false)
        }
        .task { await load() }
        .refreshable { await load() }
        .alert(errorMessage ?? "", isPresented: .constant(errorMessage != nil)) {
            Button(Loc.t("ok"), role: .cancel) { errorMessage = nil }
        }
        .alert(Loc.t("confirm_remove_friend"), isPresented: .constant(removeTarget != nil)) {
            Button(Loc.t("cancel"), role: .cancel) { removeTarget = nil }
            Button(Loc.t("delete"), role: .destructive) {
                if let removeTarget { Task { await removeFriend(removeTarget) } }
            }
        }
    }

    private var qrCard: some View {
        VStack(spacing: 0) {
            Button { showMyQR = true } label: {
                HStack {
                    Text(Loc.t("my_qr_code")).foregroundStyle(Color.appLinkText)
                    Spacer()
                    Image(systemName: "qrcode").foregroundStyle(Color.appLinkText)
                }
                .padding()
            }
            Divider().padding(.horizontal)
            Button { showScanner = true } label: {
                HStack {
                    Text(Loc.t("scan_qr_code")).foregroundStyle(Color.appLinkText)
                    Spacer()
                    Image(systemName: "qrcode.viewfinder").foregroundStyle(Color.appLinkText)
                }
                .padding()
            }
        }
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func sectionBlock<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func load() async {
        guard auth.isAuthenticated else { isLoading = false; return }
        isLoading = true
        async let f = APIClient.shared.friends()
        async let r = APIClient.shared.friendRequests()
        async let i = APIClient.shared.sessionInvites()
        friends = (try? await f) ?? []
        incomingRequests = (try? await r)?.incoming ?? []
        sessionInvites = (try? await i) ?? []
        isLoading = false
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { searchResults = []; return }
        isSearching = true
        searchResults = (try? await APIClient.shared.searchFriends(query: query)) ?? []
        isSearching = false
    }

    private func sendRequest(to user: Friend) async {
        do {
            try await APIClient.shared.sendFriendRequest(toUserId: user.userId)
            searchResults.removeAll { $0.id == user.id }
        } catch {
            errorMessage = Loc.t("error_generic")
        }
    }

    private func respond(_ request: FriendRequest, accept: Bool) async {
        incomingRequests.removeAll { $0.id == request.id }
        if accept {
            try? await APIClient.shared.acceptFriendRequest(requestId: request.id)
            await load()
        } else {
            try? await APIClient.shared.rejectFriendRequest(requestId: request.id)
        }
    }

    private func removeFriend(_ friend: Friend) async {
        removeTarget = nil
        friends.removeAll { $0.id == friend.id }
        try? await APIClient.shared.removeFriend(userId: friend.userId)
    }
}
