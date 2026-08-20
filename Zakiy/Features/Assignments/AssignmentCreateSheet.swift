import SwiftUI

/// نموذج إنشاء واجب جديد - معلم بس. يجيب فصوله وطلابه من نفس مصدر
/// TeacherRosterView (`/api/teacher/roster`)، ويقدر يختار "كل طلاب الفصل"
/// أو طالب معيّن.
struct AssignmentCreateSheet: View {
    var onCreated: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var classes: [SchoolClass] = []
    @State private var students: [SchoolStudent] = []
    @State private var selectedClassId: String?
    @State private var selectedTargetId: String?
    @State private var subject = ""
    @State private var title = ""
    @State private var content = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var studentsInSelectedClass: [SchoolStudent] {
        guard let selectedClassId else { return [] }
        return students.filter { $0.classId == selectedClassId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(Loc.t("assignment_class_label"), selection: $selectedClassId) {
                        ForEach(classes) { c in Text(c.name).tag(Optional(c.id)) }
                    }
                    Picker(Loc.t("assignment_target_label"), selection: $selectedTargetId) {
                        Text(Loc.t("assignment_target_all")).tag(String?.none)
                        ForEach(studentsInSelectedClass) { s in
                            Text(s.fullName ?? s.username).tag(Optional(s.userId))
                        }
                    }
                }
                Section {
                    TextField(Loc.t("assignment_subject_placeholder"), text: $subject)
                    TextField(Loc.t("assignment_title_placeholder"), text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 140)
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text(Loc.t("assignment_content_placeholder"))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8).padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
                Section {
                    Button {
                        Task { await create() }
                    } label: {
                        if isSaving { ProgressView().frame(maxWidth: .infinity) }
                        else { Text(Loc.t("btn_create_assignment")).frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.appPrimary)
                    .disabled(isSaving || selectedClassId == nil || subject.isEmpty || title.isEmpty)
                }
            }
            .navigationTitle(Loc.t("assignment_new_heading"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("cancel")) { dismiss() }
                }
            }
            .task { await loadRoster() }
        }
    }

    private func loadRoster() async {
        let roster = try? await APIClient.shared.teacherRoster()
        classes = roster?.classes ?? []
        students = roster?.students ?? []
        if selectedClassId == nil { selectedClassId = classes.first?.id }
    }

    private func create() async {
        guard let selectedClassId else {
            errorMessage = Loc.t("err_assignment_need_class")
            return
        }
        isSaving = true
        errorMessage = nil
        do {
            try await APIClient.shared.createAssignment(
                classId: selectedClassId,
                targetStudentId: selectedTargetId,
                subject: subject,
                title: title,
                content: content
            )
            await onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
