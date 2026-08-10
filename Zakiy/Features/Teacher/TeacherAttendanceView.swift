import SwiftUI

struct TeacherAttendanceView: View {
    let selectedClassId: String?

    @State private var autoRows: [SessionAttendanceRow] = []
    @State private var students: [SchoolStudent] = []
    @State private var isLoading = true

    @State private var date = Date()
    @State private var statuses: [String: String] = [:]
    @State private var isSaving = false
    @State private var saveMessage: String?

    var body: some View {
        List {
            Section(Loc.t("manual_attendance_heading")) {
                DatePicker(Loc.t("th_day"), selection: $date, displayedComponents: .date)
                    .onChange(of: date) { Task { await loadManual() } }

                if classStudents.isEmpty {
                    Text(Loc.t("teacher_no_students")).foregroundStyle(.secondary)
                } else {
                    ForEach(classStudents) { student in
                        HStack {
                            Text(student.username)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { statuses[student.userId] ?? "present" },
                                set: { statuses[student.userId] = $0 }
                            )) {
                                Text(Loc.t("attendance_status_present")).tag("present")
                                Text(Loc.t("attendance_status_late")).tag("late")
                                Text(Loc.t("attendance_status_absent")).tag("absent")
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    Button {
                        Task { await saveAttendance() }
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(Loc.t("btn_save_attendance")).frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSaving || selectedClassId == nil)
                    if let saveMessage {
                        Text(saveMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            Section(Loc.t("auto_attendance_heading")) {
                if isLoading {
                    ProgressView()
                } else if autoRows.isEmpty {
                    Text(Loc.t("no_schedule_yet")).foregroundStyle(.secondary)
                } else {
                    ForEach(autoRows, id: \.self) { row in
                        HStack {
                            Text(studentName(row.userId))
                            Spacer()
                            Text(row.joinedAt).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .task(id: selectedClassId) { await loadAll() }
        .refreshable { await loadAll() }
    }

    private var classStudents: [SchoolStudent] {
        guard let selectedClassId else { return [] }
        return students.filter { $0.classId == selectedClassId }
    }

    private func studentName(_ userId: String) -> String {
        students.first { $0.userId == userId }?.username ?? userId
    }

    private func loadAll() async {
        isLoading = true
        let roster = try? await APIClient.shared.teacherRoster()
        students = roster?.students ?? []
        autoRows = (try? await APIClient.shared.teacherAttendance(classId: selectedClassId)) ?? []
        await loadManual()
        isLoading = false
    }

    private func loadManual() async {
        guard let selectedClassId else { return }
        let dateString = Self.dateFormatter.string(from: date)
        let records = (try? await APIClient.shared.teacherManualAttendance(classId: selectedClassId, date: dateString)) ?? []
        statuses = Dictionary(uniqueKeysWithValues: records.map { ($0.studentId, $0.status) })
    }

    private func saveAttendance() async {
        guard let selectedClassId else { return }
        isSaving = true
        saveMessage = nil
        let dateString = Self.dateFormatter.string(from: date)
        let records = classStudents.map { (studentId: $0.userId, status: statuses[$0.userId] ?? "present") }
        do {
            try await APIClient.shared.teacherSaveManualAttendance(classId: selectedClassId, date: dateString, records: records)
            saveMessage = Loc.t("attendance_saved_msg")
        } catch {
            saveMessage = Loc.t("error_generic")
        }
        isSaving = false
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
