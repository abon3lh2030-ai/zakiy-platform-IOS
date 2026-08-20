import SwiftUI
import UniformTypeIdentifiers

/// اختيار كتاب يلخّصه المساعد الذكي - إما من مكتبتك أو رفع ملف PDF جديد.
/// onPicked يمرّر (عنوان الكتاب، النص المستخرج) لصفحة المحادثة، اللي تسكّر
/// هذي الشاشة وترسل طلب التلخيص. نفس فكرة LibraryPickerView.swift بس بتبويبين.
struct AIBookPickerView: View {
    let onPicked: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var books: [LibraryBook] = []
    @State private var isLoadingLibrary = true
    @State private var loadingBookId: String?
    @State private var showFileImporter = false
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text(Loc.t("ai_source_library")).tag(0)
                    Text(Loc.t("ai_source_upload")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red).padding(.horizontal)
                }

                if selectedTab == 0 {
                    libraryTab
                } else {
                    uploadTab
                }
            }
            .background(Color.appBackground)
            .navigationTitle(Loc.t("ai_summarize_book"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(Loc.t("cancel")) { dismiss() } }
            }
            .task { await loadLibrary() }
        }
    }

    private var libraryTab: some View {
        Group {
            if isLoadingLibrary {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if books.isEmpty {
                ContentUnavailableView(Loc.t("library"), systemImage: "books.vertical", description: Text(Loc.t("library_empty")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(books) { book in
                    Button {
                        Task { await pickLibraryBook(book) }
                    } label: {
                        HStack {
                            Text(book.title)
                            Spacer()
                            if loadingBookId == book.id { ProgressView() }
                        }
                    }
                    .disabled(loadingBookId != nil)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var uploadTab: some View {
        VStack(spacing: 16) {
            Spacer()
            if isUploading {
                ProgressView()
            } else {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                Text(Loc.t("ai_upload_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Button(Loc.t("ai_pick_file")) { showFileImporter = true }
                    .buttonStyle(.appPrimary)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url): Task { await uploadFile(url: url) }
            case .failure: errorMessage = Loc.t("error_generic")
            }
        }
    }

    private func loadLibrary() async {
        isLoadingLibrary = true
        books = (try? await APIClient.shared.libraryBooks()) ?? []
        isLoadingLibrary = false
    }

    private func pickLibraryBook(_ book: LibraryBook) async {
        loadingBookId = book.id
        errorMessage = nil
        do {
            let detail = try await APIClient.shared.libraryBook(id: book.id)
            onPicked(detail.title, detail.extractedText)
        } catch {
            errorMessage = error.localizedDescription
        }
        loadingBookId = nil
    }

    private func uploadFile(url: URL) async {
        isUploading = true
        errorMessage = nil
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = Loc.t("error_generic")
            isUploading = false
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let filename = try await APIClient.shared.upload(fileURL: url)
            let text = try await APIClient.shared.extractText(filename: filename)
            let bookTitle = url.deletingPathExtension().lastPathComponent
            onPicked(bookTitle, text)
        } catch {
            errorMessage = error.localizedDescription
            isUploading = false
        }
    }
}
