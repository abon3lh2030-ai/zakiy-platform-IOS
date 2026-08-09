import SwiftUI
import UniformTypeIdentifiers

struct LibraryListView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var books: [LibraryBook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var renamingBook: LibraryBook?
    @State private var renameText = ""
    @State private var deletingBook: LibraryBook?
    @State private var selectedBook: LibraryBook?
    @State private var showFileImporter = false
    @State private var isUploading = false
    @State private var pendingExtractedText: String?
    @State private var newBookTitle = ""

    var body: some View {
        Group {
            if !auth.isAuthenticated {
                ContentUnavailableView(
                    Loc.t("library"),
                    systemImage: "books.vertical",
                    description: Text(Loc.t("library_guest_gate"))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView(Loc.t("loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if books.isEmpty {
                ContentUnavailableView(Loc.t("library"), systemImage: "books.vertical", description: Text(Loc.t("library_empty")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(books) { book in
                        HStack(spacing: 10) {
                            Button {
                                selectedBook = book
                            } label: {
                                Text(book.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button(Loc.t("rename")) {
                                renameText = book.title
                                renamingBook = book
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .controlSize(.small)

                            Button(Loc.t("delete"), role: .destructive) {
                                deletingBook = book
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("library"))
        .toolbar {
            if auth.isAuthenticated {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label(Loc.t("add_book"), systemImage: "plus")
                    }
                    .disabled(isUploading)
                }
            }
        }
        .overlay {
            if isUploading {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView(Loc.t("loading"))
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url): Task { await uploadForLibrary(url: url) }
            case .failure: errorMessage = Loc.t("error_generic")
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(item: $selectedBook) { book in
            LibraryDetailView(bookId: book.id, title: book.title)
        }
        .alert(Loc.t("rename_book_title"), isPresented: .constant(renamingBook != nil)) {
            TextField(Loc.t("book_title_placeholder"), text: $renameText)
            Button(Loc.t("cancel"), role: .cancel) { renamingBook = nil }
            Button(Loc.t("save")) {
                if let book = renamingBook { Task { await renameBook(book) } }
            }
            .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .alert(Loc.t("confirm_delete_book"), isPresented: .constant(deletingBook != nil)) {
            Button(Loc.t("cancel"), role: .cancel) { deletingBook = nil }
            Button(Loc.t("delete"), role: .destructive) {
                if let book = deletingBook {
                    deletingBook = nil
                    Task { await deleteBook(book) }
                }
            }
        }
        .alert(Loc.t("save_to_library_title"), isPresented: .constant(pendingExtractedText != nil)) {
            TextField(Loc.t("book_title_placeholder"), text: $newBookTitle)
            Button(Loc.t("cancel"), role: .cancel) { pendingExtractedText = nil }
            Button(Loc.t("save")) { Task { await saveNewBook() } }
                .disabled(newBookTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .alert(errorMessage ?? "", isPresented: .constant(errorMessage != nil)) {
            Button(Loc.t("ok"), role: .cancel) { errorMessage = nil }
        }
    }

    private func load() async {
        guard auth.isAuthenticated else { isLoading = false; return }
        isLoading = true
        do {
            books = try await APIClient.shared.libraryBooks()
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isLoading = false
    }

    private func deleteBook(_ book: LibraryBook) async {
        books.removeAll { $0.id == book.id }
        try? await APIClient.shared.deleteLibraryBook(id: book.id)
    }

    private func uploadForLibrary(url: URL) async {
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = Loc.t("error_generic")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let filename = try await APIClient.shared.upload(fileURL: url)
            let text = try await APIClient.shared.extractText(filename: filename)
            newBookTitle = url.deletingPathExtension().lastPathComponent
            pendingExtractedText = text
        } catch {
            errorMessage = Loc.t("error_generic")
        }
    }

    private func saveNewBook() async {
        let title = newBookTitle.trimmingCharacters(in: .whitespaces)
        guard let text = pendingExtractedText, !title.isEmpty else { return }
        pendingExtractedText = nil
        do {
            _ = try await APIClient.shared.createLibraryBook(title: title, extractedText: text)
            await load()
        } catch {
            errorMessage = Loc.t("error_generic")
        }
    }

    private func renameBook(_ book: LibraryBook) async {
        let newTitle = renameText.trimmingCharacters(in: .whitespaces)
        renamingBook = nil
        guard !newTitle.isEmpty else { return }
        do {
            try await APIClient.shared.renameLibraryBook(id: book.id, title: newTitle)
            if let index = books.firstIndex(where: { $0.id == book.id }) {
                books[index] = LibraryBook(id: book.id, title: newTitle, createdAt: book.createdAt)
            }
        } catch {
            errorMessage = Loc.t("error_generic")
        }
    }
}

struct LibraryDetailView: View {
    let bookId: String
    let title: String

    @State private var detail: LibraryBookDetail?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView(Loc.t("loading")).padding(.top, 60)
            } else if let detail {
                NavigationLink {
                    StudyHubView(sourceText: detail.extractedText)
                } label: {
                    Label(Loc.t("open_for_study"), systemImage: "book")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.appPrimary)
                .padding()

                Text(detail.extractedText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .background(Color.appBackground)
        .navigationTitle(title)
        .task {
            detail = try? await APIClient.shared.libraryBook(id: bookId)
            isLoading = false
        }
    }
}
