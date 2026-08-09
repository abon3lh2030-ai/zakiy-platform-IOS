import SwiftUI

struct ArchiveListView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var items: [SessionArchiveItem] = []
    @State private var isLoading = true
    @State private var selected: SessionArchiveItem?

    var body: some View {
        Group {
            if !auth.isAuthenticated {
                ContentUnavailableView(Loc.t("archive"), systemImage: "archivebox", description: Text(Loc.t("archive_guest_gate")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                ContentUnavailableView(Loc.t("archive"), systemImage: "archivebox", description: Text(Loc.t("archive_empty")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { item in
                    Button { selected = item } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.hostName.map { String(format: Loc.t("session_hosted_by"), $0) } ?? item.roomCode ?? Loc.t("archive"))
                                .font(.headline)
                            HStack(spacing: 8) {
                                if let mine = myParticipant(in: item) {
                                    Label("\(mine.score ?? 0)/\(mine.total ?? 0)", systemImage: "checkmark.circle")
                                }
                                if let createdAt = item.createdAt {
                                    Text(createdAt)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("archive"))
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(item: $selected) { item in
            ArchiveDetailView(item: item)
        }
    }

    private func myParticipant(in item: SessionArchiveItem) -> ArchiveParticipant? {
        item.participants?.first { $0.userId == auth.userId }
    }

    private func load() async {
        guard auth.isAuthenticated else { isLoading = false; return }
        isLoading = true
        items = (try? await APIClient.shared.sessionsArchive()) ?? []
        isLoading = false
    }
}
