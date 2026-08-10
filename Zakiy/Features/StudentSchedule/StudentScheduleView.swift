import SwiftUI

/// جدول حصص الطالب (لحساب طالب مرتبط بمدرسة بس) - تبويب إضافي بالتبويبات
/// الرئيسية، بدون أي تغيير على تجربة الحساب الفردي العادي.
struct StudentScheduleView: View {
    @State private var schedule: [ClassScheduleEntry] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else if schedule.isEmpty {
                Text(Loc.t("no_schedule_yet")).foregroundStyle(.secondary)
            } else {
                ForEach(schedule) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(WeekDay.label(entry.dayOfWeek)).font(.subheadline.bold())
                        Text("\(entry.startTime) - \(entry.endTime)").font(.caption).foregroundStyle(.secondary)
                        if let subject = entry.subject, !subject.isEmpty {
                            Text(subject).font(.caption)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("student_schedule_heading"))
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        schedule = (try? await APIClient.shared.studentSchedule()) ?? []
        isLoading = false
    }
}
