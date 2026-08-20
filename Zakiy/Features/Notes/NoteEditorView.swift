import SwiftUI

/// صفحة ملاحظة وحدة - كل ملاحظة تفتح بصفحتها الخاصة (مو تعديل داخل القائمة).
/// حفظ تلقائي (debounce) للعنوان/المحتوى، وفوري لبقية الحقول (مجلد/تثبيت/
/// نوع/عناصر التو-دو). نستخدم متغيرات @State مسطّحة بدل Binding مخصص متداخل
/// على struct وحدة - يخفّف الحمل عن type-checker السويفت (كان يفشل بالبناء
/// بخطأ "unable to type-check this expression in reasonable time").
struct NoteEditorView: View {
    let noteId: String
    let folders: [NoteFolder]
    var onChanged: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var saveTask: Task<Void, Never>?
    @State private var showDeleteConfirm = false
    @State private var newChecklistText = ""

    @State private var title = ""
    @State private var content = ""
    @State private var folderId: String = ""
    @State private var noteType = "text"
    @State private var checklistItems: [ChecklistItem] = []
    @State private var isPinned = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    fieldsSection
                    if noteType == "checklist" {
                        checklistSection
                    } else {
                        contentSection
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(title.isEmpty ? Loc.t("notes_untitled") : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert(Loc.t("notes_delete_confirm"), isPresented: $showDeleteConfirm) {
            Button(Loc.t("cancel"), role: .cancel) {}
            Button(Loc.t("delete"), role: .destructive) { Task { await deleteNote() } }
        }
        .task { await load() }
        .onDisappear { onChanged() }
    }

    private var fieldsSection: some View {
        Section {
            TextField(Loc.t("note_title_placeholder"), text: $title)
                .font(.title3.weight(.semibold))
                .onChange(of: title) { scheduleSave(["title": title]) }

            Picker(Loc.t("note_folder_label"), selection: $folderId) {
                Text(Loc.t("notes_folder_unfiled")).tag("")
                ForEach(folders) { folder in
                    Text(folder.name).tag(folder.id)
                }
            }
            .onChange(of: folderId) {
                saveNow(["folder_id": folderId.isEmpty ? NSNull() : folderId])
            }

            Picker("", selection: $noteType) {
                Text(Loc.t("note_type_text")).tag("text")
                Text(Loc.t("note_type_checklist")).tag("checklist")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: noteType) { saveNow(["note_type": noteType]) }
        }
    }

    private var contentSection: some View {
        Section {
            TextEditor(text: $content)
                .frame(minHeight: 260)
                .onChange(of: content) { scheduleSave(["content": content]) }
        }
    }

    private var checklistSection: some View {
        Section {
            ForEach(Array(checklistItems.enumerated()), id: \.offset) { index, item in
                checklistRow(index: index, item: item)
            }
            .onDelete { offsets in
                checklistItems.remove(atOffsets: offsets)
                saveNow(["checklist_items": encodedChecklist()])
            }

            HStack {
                TextField(Loc.t("note_checklist_add_placeholder"), text: $newChecklistText)
                Button(action: addChecklistItem) {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
    }

    private func checklistRow(index: Int, item: ChecklistItem) -> some View {
        HStack {
            Button {
                checklistItems[index].done.toggle()
                saveNow(["checklist_items": encodedChecklist()])
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.done ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            TextField("", text: Binding(
                get: { checklistItems[index].text },
                set: { newValue in
                    checklistItems[index].text = newValue
                    scheduleSave(["checklist_items": encodedChecklist()])
                }
            ))
            .strikethrough(item.done)
            .foregroundStyle(item.done ? .secondary : .primary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button {
                    isPinned.toggle()
                    saveNow(["is_pinned": isPinned])
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        do {
            let note = try await APIClient.shared.note(id: noteId)
            title = note.title
            content = note.content
            folderId = note.folderId ?? ""
            noteType = note.noteType
            checklistItems = note.checklistItems
            isPinned = note.isPinned
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteNote() async {
        do {
            try await APIClient.shared.deleteNote(id: noteId)
            onChanged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func encodedChecklist() -> [[String: Any]] {
        checklistItems.map { ["text": $0.text, "done": $0.done] }
    }

    private func addChecklistItem() {
        let text = newChecklistText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        checklistItems.append(ChecklistItem(text: text, done: false))
        newChecklistText = ""
        saveNow(["checklist_items": encodedChecklist()])
    }

    /// حفظ فوري لتغييرات منفصلة (مجلد/نوع/تثبيت/عناصر تو-دو)
    private func saveNow(_ patch: [String: Any]) {
        saveTask?.cancel()
        saveTask = Task {
            do {
                _ = try await APIClient.shared.updateNote(id: noteId, patch: patch)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// حفظ مؤجّل (debounce) للحقول اللي تُكتب بشكل مستمر (عنوان/محتوى) -
    /// يمنع إرسال طلب PATCH مع كل ضغطة زر
    private func scheduleSave(_ patch: [String: Any]) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            do {
                _ = try await APIClient.shared.updateNote(id: noteId, patch: patch)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
