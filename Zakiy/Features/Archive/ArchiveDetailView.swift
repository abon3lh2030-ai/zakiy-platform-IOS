import SwiftUI

struct ArchiveDetailView: View {
    let item: SessionArchiveItem

    @State private var participants: [ArchiveParticipant] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.roomName).font(.title2.bold())
                    Text(item.date, style: .date).font(.subheadline).foregroundStyle(.secondary)
                    Label("\(Loc.t("your_score")): \(item.score)/\(item.total)", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.accentColor)
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
                } else if !participants.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Loc.t("participants")).font(.headline)
                        ForEach(participants) { p in
                            HStack {
                                Text(p.username)
                                Spacer()
                                Text("\(p.score)/\(p.total)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                    .padding()
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("archive"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            participants = (try? await APIClient.shared.sessionArchiveParticipants(sessionId: item.id)) ?? []
            isLoading = false
        }
    }
}
