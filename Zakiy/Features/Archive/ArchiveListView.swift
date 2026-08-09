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
                            Text(item.roomName).font(.headline)
                            HStack(spacing: 8) {
                                Label("\(item.score)/\(item.total)", systemImage: "checkmark.circle")
                                Text(item.date, style: .date)
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

    private func load() async {
        guard auth.isAuthenticated else { isLoading = false; return }
        isLoading = true
        items = (try? await APIClient.shared.sessionArchive()) ?? []
        isLoading = false
    }
}
