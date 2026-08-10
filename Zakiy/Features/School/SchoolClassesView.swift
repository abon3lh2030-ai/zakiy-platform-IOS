import SwiftUI

struct SchoolClassesView: View {
    @State private var classes: [SchoolClass] = []
    @State private var teachers: [TeacherSummary] = []
    @State private var isLoading = true

    @State private var newClassName = ""
    @State private var selectedTeacherId: String?
    @State private var isSaving = false
    @State private var formError: String?

    var body: some View {
        List {
            Section(Loc.t("btn_add_class")) {
                TextField(Loc.t("ph_class_name"), text: $newClassName)
                Picker(Loc.t("th_teacher"), selection: $selectedTeacherId) {
                    Text(Loc.t("opt_no_teacher_yet")).tag(String?.none)
                    ForEach(teachers) { t in
                        Text(t.username).tag(Optional(t.userId))
                    }
                }
                Button {
                    Task { await addClass() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("btn_add_class")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving || newClassName.trimmingCharacters(in: .whitespaces).isEmpty)
                if let formError {
                    Text(formError).font(.footnote).foregroundStyle(.red)
                }
            }

            Section {
                if isLoading {
                    ProgressView()
                } else if classes.isEmpty {
                    Text(Loc.t("school_no_classes")).foregroundStyle(.secondary)
                } else {
                    ForEach(classes) { cls in
                        NavigationLink {
                            ClassScheduleView(schoolClass: cls, teachers: teachers, onChanged: { Task { await load() } })
                        } label: {
                            classRow(cls)
                        }
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func classRow(_ cls: SchoolClass) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cls.name).font(.headline)
            Text(teachers.first { $0.userId == cls.teacherId }?.username ?? Loc.t("opt_no_teacher_yet"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        isLoading = true
        async let classesTask = APIClient.shared.schoolClasses()
        async let teachersTask = APIClient.shared.schoolTeachers()
        classes = (try? await classesTask) ?? []
        teachers = (try? await teachersTask) ?? []
        isLoading = false
    }

    private func addClass() async {
        formError = nil
        isSaving = true
        do {
            _ = try await APIClient.shared.schoolCreateClass(
                name: newClassName.trimmingCharacters(in: .whitespaces),
                teacherId: selectedTeacherId
            )
            newClassName = ""
            selectedTeacherId = nil
            await load()
        } catch {
            formError = Loc.t("error_generic")
        }
        isSaving = false
    }
}

/// شاشة تفاصيل فصل وحد: تغيير المعلم المسؤول، إدارة جدول حصصه، وحذفه -
/// تُفتح من `SchoolClassesView` والمعلم ما يوصلها (تعديل هيكلي مقصور على
/// مدير/إداري المدرسة).
struct ClassScheduleView: View {
    let schoolClass: SchoolClass
    let teachers: [TeacherSummary]
    var onChanged: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTeacherId: String?
    @State private var schedule: [ClassScheduleEntry] = []
    @State private var isLoading = true

    @State private var selectedDay = 0
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var subject = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section(Loc.t("th_teacher")) {
                Picker(Loc.t("th_teacher"), selection: $selectedTeacherId) {
                    Text(Loc.t("opt_no_teacher_yet")).tag(String?.none)
                    ForEach(teachers) { t in
                        Text(t.username).tag(Optional(t.userId))
                    }
                }
                .onChange(of: selectedTeacherId) {
                    Task {
                        try? await APIClient.shared.schoolReassignClassTeacher(classId: schoolClass.id, teacherId: selectedTeacherId)
                        onChanged()
                    }
                }
            }

            Section(Loc.t("btn_add_schedule")) {
                Picker(Loc.t("th_day"), selection: $selectedDay) {
                    ForEach(0..<7, id: \.self) { day in
                        Text(WeekDay.label(day)).tag(day)
                    }
                }
                DatePicker(Loc.t("th_time"), selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker(Loc.t("th_time"), selection: $endTime, displayedComponents: .hourAndMinute)
                TextField(Loc.t("ph_subject"), text: $subject)
                Button {
                    Task { await addSchedule() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("btn_add_schedule")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving)
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
            }

            Section(Loc.t("schedule_heading")) {
                if isLoading {
                    ProgressView()
                } else if schedule.isEmpty {
                    Text(Loc.t("no_schedule_yet")).foregroundStyle(.secondary)
                } else {
                    ForEach(schedule) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(WeekDay.label(entry.dayOfWeek)).font(.subheadline.bold())
                                Text("\(entry.startTime) - \(entry.endTime)").font(.caption).foregroundStyle(.secondary)
                                if let subj = entry.subject, !subj.isEmpty {
                                    Text(subj).font(.caption)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task { await deleteSchedule(entry) }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button(Loc.t("btn_delete"), role: .destructive) {
                    Task { await deleteClass() }
                }
            }
        }
        .navigationTitle(schoolClass.name)
        .task {
            selectedTeacherId = schoolClass.teacherId
            await load()
        }
    }

    private func load() async {
        isLoading = true
        schedule = (try? await APIClient.shared.schoolClassSchedule(classId: schoolClass.id)) ?? []
        isLoading = false
    }

    private func addSchedule() async {
        errorMessage = nil
        isSaving = true
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        do {
            try await APIClient.shared.schoolAddSchedule(
                classId: schoolClass.id, dayOfWeek: selectedDay,
                startTime: formatter.string(from: startTime), endTime: formatter.string(from: endTime),
                subject: subject.trimmingCharacters(in: .whitespaces)
            )
            subject = ""
            await load()
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isSaving = false
    }

    private func deleteSchedule(_ entry: ClassScheduleEntry) async {
        try? await APIClient.shared.schoolDeleteSchedule(id: entry.id)
        await load()
    }

    private func deleteClass() async {
        try? await APIClient.shared.schoolDeleteClass(classId: schoolClass.id)
        onChanged()
        dismiss()
    }
}
