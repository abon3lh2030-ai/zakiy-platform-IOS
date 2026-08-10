import SwiftUI

struct TeacherPerformanceView: View {
    let selectedClassId: String?

    @State private var rows: [TeacherPerformanceRow] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if rows.isEmpty {
                Text(Loc.t("teacher_no_students")).foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.username).font(.headline)
                        HStack {
                            Text("\(Loc.t("th_attempts")): \(row.attemptsCount)")
                            Spacer()
                            Text("\(Loc.t("th_avg_score")): \(row.avgScore)%")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text("\(Loc.t("th_study_minutes")): \(row.totalStudyMinutes)")
                            Spacer()
                            Text("\(Loc.t("th_streak")): \(row.currentStreak)")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .task(id: selectedClassId) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        rows = (try? await APIClient.shared.teacherPerformance(classId: selectedClassId)) ?? []
        isLoading = false
    }
}
