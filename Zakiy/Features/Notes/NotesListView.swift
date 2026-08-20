import SwiftUI

/// دفتر الملاحظات - حساب فردي بس (يُخفى تمامًا لأي حساب مؤسسي عبر شرط
/// auth.role == nil بمكان الاستدعاء بـ SettingsView). مجلدات + بحث + تثبيت +
/// ملاحظة نصية أو تو-دو ليست، كل ملاحظة بصفحتها الخاصة (NoteEditorView).
struct NotesListView: View {
    @State private var folders: [NoteFolder] = []
    @State private var notes: [NoteSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var activeFolder: FolderFilter = .all
    @State private var openedNote: NoteRoute?
    @State private var showNewFolderPrompt = false
    @State private var newFolderName = ""
    @State private var folderPendingDeletion: NoteFolder?

    enum FolderFilter: Equatable {
        case all
        case unfiled
        case folder(String)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    folderChipsRow
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.caption).padding(.horizontal)
                    }
                    if visibleNotes.isEmpty {
                        ContentUnavailableView(Loc.t("notes"), systemImage: "note.text", description: Text(Loc.t("notes_empty")))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(visibleNotes) { note in
                            Button { openedNote = NoteRoute(id: note.id) } label: {
                                NoteRow(note: note, folderName: folders.first { $0.id == note.folderId }?.name)
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("notes"))
        .searchable(text: $searchText, prompt: Loc.t("notes_search_placeholder"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await createNewNote() }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: searchText) { Task { await loadNotes() } }
        .onChange(of: activeFolder) { Task { await loadNotes() } }
        .navigationDestination(item: $openedNote) { route in
            NoteEditorView(noteId: route.id, folders: folders) {
                Task { await loadNotes() }
            }
        }
        .alert(Loc.t("notes_new_folder"), isPresented: $showNewFolderPrompt) {
            TextField(Loc.t("notes_folder_name_placeholder"), text: $newFolderName)
            Button(Loc.t("cancel"), role: .cancel) { newFolderName = "" }
            Button(Loc.t("save")) { Task { await addFolder() } }
        }
        .alert(item: $folderPendingDeletion) { folder in
            Alert(
                title: Text(Loc.t("notes_delete_folder_confirm")),
                primaryButton: .destructive(Text(Loc.t("delete"))) { Task { await deleteFolder(folder) } },
                secondaryButton: .cancel(Text(Loc.t("cancel")))
            )
        }
    }

    private var visibleNotes: [NoteSummary] {
        switch activeFolder {
        case .unfiled: return notes.filter { $0.folderId == nil }
        default: return notes
        }
    }

    private var folderChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: Loc.t("notes_folder_all"), isActive: activeFolder == .all) { activeFolder = .all }
                chip(title: Loc.t("notes_folder_unfiled"), isActive: activeFolder == .unfiled) { activeFolder = .unfiled }
                ForEach(folders) { folder in
                    chip(title: folder.name, isActive: activeFolder == .folder(folder.id)) {
                        activeFolder = .folder(folder.id)
                    } onDelete: {
                        folderPendingDeletion = folder
                    }
                }
                chip(title: "+ \(Loc.t("notes_new_folder"))", isActive: false) { showNewFolderPrompt = true }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private func chip(title: String, isActive: Bool, onTap: @escaping () -> Void, onDelete: (() -> Void)? = nil) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.caption.weight(.medium))
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.system(size: 9))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor : Color.appCard, in: Capsule())
        .foregroundStyle(isActive ? Color.appAccentText : .primary)
        .overlay(Capsule().stroke(.quaternary, lineWidth: isActive ? 0 : 1))
        .onTapGesture(perform: onTap)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let foldersTask = APIClient.shared.noteFolders()
            async let notesTask = APIClient.shared.notes()
            folders = try await foldersTask
            notes = try await notesTask
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadNotes() async {
        do {
            let folderId: String?
            switch activeFolder {
            case .folder(let id): folderId = id
            default: folderId = nil
            }
            notes = try await APIClient.shared.notes(folderId: folderId, query: searchText.isEmpty ? nil : searchText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createNewNote() async {
        let folderId: String?
        switch activeFolder {
        case .folder(let id): folderId = id
        default: folderId = nil
        }
        do {
            let note = try await APIClient.shared.createNote(folderId: folderId)
            openedNote = NoteRoute(id: note.id)
            await loadNotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addFolder() async {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        newFolderName = ""
        guard !name.isEmpty else { return }
        do {
            _ = try await APIClient.shared.createNoteFolder(name: name)
            folders = try await APIClient.shared.noteFolders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteFolder(_ folder: NoteFolder) async {
        do {
            try await APIClient.shared.deleteNoteFolder(id: folder.id)
            if activeFolder == .folder(folder.id) { activeFolder = .all }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct NoteRow: View {
    let note: NoteSummary
    let folderName: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: note.noteType == "checklist" ? "checklist" : "note.text")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title.trimmingCharacters(in: .whitespaces).isEmpty ? Loc.t("notes_untitled") : note.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(note.title.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .primary)
                HStack(spacing: 8) {
                    if let folderName {
                        Label(folderName, systemImage: "folder").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if note.isPinned {
                Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

/// غلاف بسيط عشان navigationDestination(item:) يحتاج نوع Identifiable -
/// بدل ما نوسّع String نفسه (تعديل عام على نوع ما نملكه، يأثر على كل الملف
/// التنفيذي، أفضل نتجنبه)
struct NoteRoute: Identifiable, Hashable {
    let id: String
}
