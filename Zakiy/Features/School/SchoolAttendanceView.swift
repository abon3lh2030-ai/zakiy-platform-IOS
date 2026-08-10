import SwiftUI

struct SchoolAttendanceView: View {
    @State private var report: SchoolAttendanceReport?
    @State private var students: [SchoolStudent] = []
    @State private var selectedClassId: String?
    @State private var isLoading = true

    var body: some View {
        List {
            if let report {
                Picker(Loc.t("opt_all_classes"), selection: $selectedClassId) {
                    Text(Loc.t("opt_all_classes")).tag(String?.none)
                    ForEach(report.classes) { c in
                        Text(c.name).tag(Optional(c.id))
                    }
                }
                .onChange(of: selectedClassId) { Task { await load() } }

                Section(Loc.t("auto_attendance_heading")) {
                    if report.attendance.isEmpty {
                        Text(Loc.t("no_schedule_yet")).foregroundStyle(.secondary)
                    } else {
                        ForEach(report.attendance, id: \.self) { row in
                            HStack {
                                Text(studentName(row.userId))
                                Spacer()
                                Text(row.joinedAt).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section(Loc.t("manual_attendance_heading")) {
                    if report.manualAttendance.isEmpty {
                        Text(Loc.t("no_schedule_yet")).foregroundStyle(.secondary)
                    } else {
                        ForEach(report.manualAttendance, id: \.self) { row in
                            HStack {
                                Text(studentName(row.studentId))
                                Spacer()
                                Text(Loc.t("attendance_status_" + row.status)).font(.caption.bold())
                                Text(row.sessionDate ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func studentName(_ userId: String) -> String {
        students.first { $0.userId == userId }?.username ?? userId
    }

    private func load() async {
        isLoading = true
        async let reportTask = APIClient.shared.schoolAttendance(classId: selectedClassId)
        async let studentsTask = APIClient.shared.schoolStudents()
        report = try? await reportTask
        students = (try? await studentsTask) ?? []
        isLoading = false
    }
}
