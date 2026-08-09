import SwiftUI
import Charts

struct PerformanceDashboardView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var data: PerformanceData?
    @State private var isLoading = true

    private var averageScore: Double {
        guard let attempts = data?.attempts, !attempts.isEmpty else { return 0 }
        let percentages = attempts.map { $0.total > 0 ? Double($0.score) / Double($0.total) * 100 : 0 }
        return percentages.reduce(0, +) / Double(percentages.count)
    }

    var body: some View {
        Group {
            if !auth.isAuthenticated {
                ContentUnavailableView(Loc.t("performance"), systemImage: "chart.line.uptrend.xyaxis", description: Text(Loc.t("performance_guest_gate")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView(Loc.t("loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let data, !data.attempts.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        summaryRow(data)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(Loc.t("progress_over_time")).font(.headline)
                            Chart(Array(data.attempts.enumerated()), id: \.offset) { index, attempt in
                                let percentage = attempt.total > 0 ? Double(attempt.score) / Double(attempt.total) * 100 : 0
                                LineMark(
                                    x: .value(Loc.t("date"), index),
                                    y: .value(Loc.t("score_percent"), percentage)
                                )
                                .foregroundStyle(Color.accentColor)
                                .symbol(Circle())
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 200)
                        }
                        .padding()
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))

                        if !data.weakTopics.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(Loc.t("weak_topics")).font(.headline)
                                ForEach(data.weakTopics) { topic in
                                    HStack {
                                        Text(topic.topic)
                                        Spacer()
                                        Text("\(topic.count)×").foregroundStyle(.secondary)
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: Loc.t("total_attempts"), value: "\(data.attempts.count)")
            statCard(title: Loc.t("average_score"), value: String(format: "%.0f%%", averageScore))
            statCard(title: Loc.t("current_streak"), value: "\(data.currentStreak)")
            statCard(title: Loc.t("longest_streak"), value: "\(data.longestStreak)")
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
        data = try? await APIClient.shared.performance()
        isLoading = false
    }
}
