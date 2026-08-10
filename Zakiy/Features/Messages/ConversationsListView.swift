import SwiftUI

struct ConversationsListView: View {
    @State private var conversations: [ConversationSummary] = []
    @State private var isLoading = true

    @State private var searchText = ""
    @State private var searchResults: [Friend] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                TextField(Loc.t("ph_search_username"), text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            await search(newValue)
                        }
                    }
                if !searchResults.isEmpty {
                    ForEach(searchResults) { user in
                        NavigationLink {
                            ConversationThreadView(userId: user.userId, username: user.username)
                        } label: {
                            Text(user.username)
                        }
                    }
                } else if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(Loc.t("no_users_found")).foregroundStyle(.secondary)
                }
            }

            Section {
                if isLoading {
                    ProgressView()
                } else if conversations.isEmpty {
                    Text(Loc.t("no_conversations_yet")).foregroundStyle(.secondary)
                } else {
                    ForEach(conversations) { convo in
                        NavigationLink {
                            ConversationThreadView(userId: convo.userId, username: convo.username)
                        } label: {
                            conversationRow(convo)
                        }
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func conversationRow(_ convo: ConversationSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(convo.username).font(.headline)
                if let last = convo.lastMessage {
                    Text(last).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if convo.unreadCount > 0 {
                Text("\(convo.unreadCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.red, in: Circle())
            }
        }
    }

    private func load() async {
        isLoading = true
        conversations = (try? await APIClient.shared.conversations()) ?? []
        isLoading = false
    }

    private func search(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { searchResults = []; return }
        searchResults = (try? await APIClient.shared.searchFriends(query: trimmed)) ?? []
    }
}
