import SwiftUI

struct FriendsListView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var friends: [Friend] = []
    @State private var incomingRequests: [FriendRequest] = []
    @State private var isLoading = true
    @State private var showMyQR = false
    @State private var showScanner = false
    @State private var searchText = ""
    @State private var searchResults: [Friend] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !auth.isAuthenticated {
                ContentUnavailableView(Loc.t("friends"), systemImage: "person.2", description: Text(Loc.t("friends_guest_gate")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        TextField(Loc.t("search_by_username"), text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await search() } }
                    }

                    if isSearching {
                        ProgressView()
                    } else if !searchResults.isEmpty {
                        Section(Loc.t("search_results")) {
                            ForEach(searchResults) { user in
                                HStack {
                                    Text(user.username)
                                    Spacer()
                                    Button(Loc.t("add_friend")) {
                                        Task { await sendRequest(to: user) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }

                    if !incomingRequests.isEmpty {
                        Section(Loc.t("friend_requests")) {
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
                            }
                        }
                    }

                    Section(Loc.t("my_friends")) {
                        if friends.isEmpty {
                            Text(Loc.t("no_friends_yet")).foregroundStyle(.secondary)
                        } else {
                            ForEach(friends) { friend in
                                NavigationLink {
                                    ProfileView(userId: friend.userId)
                                } label: {
                                    Text(friend.username)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("friends"))
        .toolbar {
            if auth.isAuthenticated {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showMyQR = true } label: {
                            Label(Loc.t("my_qr_code"), systemImage: "qrcode")
                        }
                        Button { showScanner = true } label: {
                            Label(Loc.t("scan_qr_code"), systemImage: "qrcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "qrcode")
                    }
                }
            }
        }
        .sheet(isPresented: $showMyQR) { MyQRCodeView() }
        .sheet(isPresented: $showScanner) { QRScannerView() }
        .task { await load() }
        .refreshable { await load() }
        .alert(errorMessage ?? "", isPresented: .constant(errorMessage != nil)) {
            Button(Loc.t("ok"), role: .cancel) { errorMessage = nil }
        }
    }

    private func load() async {
        guard auth.isAuthenticated else { isLoading = false; return }
        isLoading = true
        async let f = APIClient.shared.friends()
        async let r = APIClient.shared.friendRequests()
        friends = (try? await f) ?? []
        incomingRequests = (try? await r)?.incoming ?? []
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
}
