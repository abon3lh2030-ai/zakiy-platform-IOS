import SwiftUI

struct ArchiveDetailView: View {
    let item: SessionArchiveItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.hostName.map { String(format: Loc.t("session_hosted_by"), $0) } ?? item.roomCode ?? Loc.t("archive"))
                        .font(.title2.bold())
                    if let createdAt = item.createdAt {
                        Text(createdAt).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))

                if let participants = item.participants, !participants.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Loc.t("participants")).font(.headline)
                        ForEach(Array(participants.enumerated()), id: \.offset) { _, p in
                            HStack {
                                Text(p.name ?? Loc.t("default_student_name"))
                                Spacer()
                                Text("\(p.score ?? 0)/\(p.total ?? 0)")
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
    }
}
