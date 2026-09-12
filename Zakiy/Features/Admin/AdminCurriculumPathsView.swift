import SwiftUI
import UniformTypeIdentifiers

struct AdminCurriculumPathsView: View {
    @State private var paths: [CurriculumPath] = []
    @State private var name = ""
    @State private var selectedPathId = ""
    @State private var bookTitle = ""
    @State private var extractedText: String?
    @State private var showImporter = false
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("إنشاء مسار كتب") {
                TextField("اسم المسار", text: $name)
                Button("إنشاء المسار") { Task { await createPath() } }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
            }
            Section("رفع كتاب للمسار") {
                Picker("المسار", selection: $selectedPathId) {
                    Text("اختر مسارًا").tag("")
                    ForEach(paths) { Text($0.name).tag($0.id) }
                }
                Button("اختيار ملف PDF") { showImporter = true }
                if extractedText != nil {
                    TextField("اسم الكتاب", text: $bookTitle)
                    Button("رفع الكتاب") { Task { await addBook() } }
                        .disabled(selectedPathId.isEmpty || bookTitle.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
                }
            }
            ForEach(paths) { path in
                Section(path.name) {
                    ForEach(path.books ?? []) { book in
                        HStack {
                            Text(book.title)
                            Spacer()
                            Button(role: .destructive) { Task { await deleteBook(book.id) } } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    Button("حذف المسار", role: .destructive) { Task { await deletePath(path.id) } }
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .navigationTitle("مسارات الكتب")
        .overlay { if isBusy { ProgressView().padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
        .task { await load() }
        .refreshable { await load() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result { Task { await prepareBook(url) } }
            else { errorMessage = Loc.t("error_generic") }
        }
    }

    private func load() async {
        do { paths = try await APIClient.shared.adminCurriculumPaths() }
        catch { errorMessage = error.localizedDescription }
    }
    private func createPath() async {
        isBusy = true; defer { isBusy = false }
        do { try await APIClient.shared.adminCreateCurriculumPath(name: name.trimmingCharacters(in: .whitespaces)); name = ""; await load() }
        catch { errorMessage = error.localizedDescription }
    }
    private func prepareBook(_ url: URL) async {
        isBusy = true; defer { isBusy = false }
        guard url.startAccessingSecurityScopedResource() else { errorMessage = Loc.t("error_generic"); return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let filename = try await APIClient.shared.upload(fileURL: url)
            extractedText = try await APIClient.shared.extractText(filename: filename)
            bookTitle = url.deletingPathExtension().lastPathComponent
        } catch { errorMessage = error.localizedDescription }
    }
    private func addBook() async {
        guard let extractedText else { return }
        isBusy = true; defer { isBusy = false }
        do { try await APIClient.shared.adminAddCurriculumBook(pathId: selectedPathId, title: bookTitle, extractedText: extractedText); self.extractedText = nil; bookTitle = ""; await load() }
        catch { errorMessage = error.localizedDescription }
    }
    private func deletePath(_ id: String) async { try? await APIClient.shared.adminDeleteCurriculumPath(id: id); await load() }
    private func deleteBook(_ id: String) async { try? await APIClient.shared.adminDeleteCurriculumBook(id: id); await load() }
}
