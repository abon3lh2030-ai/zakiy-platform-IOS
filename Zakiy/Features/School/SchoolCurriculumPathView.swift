import SwiftUI

struct SchoolCurriculumPathView: View {
    @State private var state: SchoolCurriculumState?
    @State private var selected = ""
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Text("اختر مسار الأدمن العام لتظهر كتبه تلقائيًا في مكتبة المدرسة، أو اختر بدون مسار وارفع كتب المدرسة من المكتبة.")
                    .foregroundStyle(.secondary)
                Picker("المسار", selection: $selected) {
                    Text("بدون مسار").tag("")
                    ForEach(state?.paths ?? []) { path in
                        Text("\(path.name) (\(path.bookCount ?? 0) كتاب)").tag(path.id)
                    }
                }
                Button("حفظ المسار") { Task { await save() } }.disabled(isSaving)
                if let message { Text(message).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("مسار كتب المدرسة")
        .task { await load() }
    }

    private func load() async {
        do { state = try await APIClient.shared.schoolCurriculumState(); selected = state?.selectedPathId ?? "" }
        catch { message = error.localizedDescription }
    }
    private func save() async {
        isSaving = true; defer { isSaving = false }
        do { try await APIClient.shared.schoolSetCurriculumPath(id: selected.isEmpty ? nil : selected); message = "تم حفظ المسار" }
        catch { message = error.localizedDescription }
    }
}
