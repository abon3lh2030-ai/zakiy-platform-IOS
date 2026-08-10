import SwiftUI

struct TeacherScheduleView: View {
    @State private var response: TeacherScheduleResponse?
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if let response, !response.schedule.isEmpty {
                ForEach(response.schedule) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(className(entry.classId, in: response.classes)).font(.subheadline.bold())
                        Text("\(WeekDay.label(entry.dayOfWeek)) · \(entry.startTime) - \(entry.endTime)")
                            .font(.caption).foregroundStyle(.secondary)
                        if let subject = entry.subject, !subject.isEmpty {
                            Text(subject).font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text(Loc.t("no_schedule_yet")).foregroundStyle(.secondary)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func className(_ id: String?, in classes: [SchoolClass]) -> String {
        classes.first { $0.id == id }?.name ?? "—"
    }

    private func load() async {
        isLoading = true
        response = try? await APIClient.shared.teacherSchedule()
        isLoading = false
    }
}
