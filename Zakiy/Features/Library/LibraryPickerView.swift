import SwiftUI

/// A lightweight picker used from within room/study flows to pick an already-saved library book
/// instead of uploading a new PDF.
struct LibraryPickerView: View {
    let onPick: (LibraryBookDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var books: [LibraryBook] = []
    @State private var isLoading = true
    @State private var loadingBookId: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if books.isEmpty {
                    ContentUnavailableView(Loc.t("library"), systemImage: "books.vertical", description: Text(Loc.t("library_empty")))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(books) { book in
                        Button {
                            Task { await pick(book) }
                        } label: {
                            HStack {
                                Text(book.title)
                                Spacer()
                                if loadingBookId == book.id {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(loadingBookId != nil)
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle(Loc.t("library"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("cancel")) { dismiss() }
                }
            }
            .task {
                books = (try? await APIClient.shared.libraryBooks()) ?? []
                isLoading = false
            }
        }
    }

    private func pick(_ book: LibraryBook) async {
        loadingBookId = book.id
        if let detail = try? await APIClient.shared.libraryBook(id: book.id) {
            onPick(detail)
            dismiss()
        }
        loadingBookId = nil
    }
}
