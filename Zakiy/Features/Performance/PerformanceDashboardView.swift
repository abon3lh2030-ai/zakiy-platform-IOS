import SwiftUI
import Charts

struct PerformanceDashboardView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var data: PerformanceData?
    @State private var isLoading = true

    var body: some View {
        Group {
            if !auth.isAuthenticated {
                ContentUnavailableView(Loc.t("performance"), systemImage: "chart.line.uptrend.xyaxis", description: Text(Loc.t("performance_guest_gate")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView(Loc.t("loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let data {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        summaryRow(data)

                        if !data.attempts.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(Loc.t("progress_over_time")).font(.headline)
                                Chart(data.attempts) { attempt in
                                    LineMark(
                                        x: .value(Loc.t("date"), attempt.date),
                                        y: .value(Loc.t("score_percent"), attempt.percentage)
                                    )
                                    .foregroundStyle(Color.accentColor)
                                    .symbol(Circle())
                                }
                                .frame(height: 200)
                            }
                            .padding()
                            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                        }

                        if !data.weakTopics.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(Loc.t("weak_topics")).font(.headline)
                                ForEach(data.weakTopics) { topic in
                                    HStack {
                                        Text(topic.name)
                                        Spacer()
                                        Text("\(topic.missCount)×").foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(Loc.t("performance"), systemImage: "chart.line.uptrend.xyaxis", description: Text(Loc.t("performance_empty")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("performance"))
        .task { await load() }
        .refreshable { await load() }
    }

    private func summaryRow(_ data: PerformanceData) -> some View {
        HStack(spacing: 12) {
            statCard(title: Loc.t("total_attempts"), value: "\(data.totalAttempts)")
            statCard(title: Loc.t("average_score"), value: String(format: "%.0f%%", data.averageScore))
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.title2.bold()).foregroundStyle(.accentColor)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        guard auth.isAuthenticated else { isLoading = false; return }
        isLoading = true
        data = try? await APIClient.shared.performanceData()
        isLoading = false
    }
}
