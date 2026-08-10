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
            } else if let data, !data.attempts.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        summaryRow(data)
                        progressChart(data)

                        if !data.weakTopics.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Loc.t("weak_topics")).font(.headline)
                                VStack(spacing: 0) {
                                    ForEach(data.weakTopics) { topic in
                                        HStack {
                                            Text("\(topic.count)").foregroundStyle(.secondary)
                                            Spacer()
                                            Text(topic.topic)
                                        }
                                        .font(.subheadline)
                                        .padding(.vertical, 10)
                                        if topic.id != data.weakTopics.last?.id { Divider() }
                                    }
                                }
                            }
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
        HStack(spacing: 10) {
            statTile(value: "\(data.longestStreak)", icon: "trophy.fill", label: Loc.t("longest_streak_label"), tint: .orange)
            statTile(value: String(format: "%.1f", Double(data.totalStudyMinutes) / 60), icon: "clock.fill", label: Loc.t("study_hours_label"), tint: .gray)
            statTile(value: "\(data.currentStreak)", icon: "flame.fill", label: Loc.t("streak_label"), tint: Color.accentColor)
        }
    }

    private func statTile(value: String, icon: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(tint)
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func progressChart(_ data: PerformanceData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.t("score_progress_title")).font(.headline)
            Chart(Array(data.attempts.suffix(10).enumerated()), id: \.offset) { index, attempt in
                let percentage = attempt.total > 0 ? Double(attempt.score) / Double(attempt.total) * 100 : 0
                LineMark(
                    x: .value(Loc.t("attempt_axis"), index),
                    y: .value(Loc.t("percentage_axis"), percentage)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 3))
            }
            .chartXAxis(.hidden)
            .chartYScale(domain: 0...100)
            .frame(height: 180)
        }
        .padding()
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        guard auth.isAuthenticated else { isLoading = false; return }
        isLoading = true
        data = try? await APIClient.shared.performance()
        isLoading = false
    }
}
