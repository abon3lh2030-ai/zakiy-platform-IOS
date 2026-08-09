import SwiftUI
import UniformTypeIdentifiers

/// Sheet the host uses to prepare a quiz for the room: paste text, upload a PDF, or pick a
/// saved library book, then generate AI questions and hand them back to the room.
struct RoomStudySetupSheet: View {
    let onStart: ([QuizQuestion], Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var sourceText = ""
    @State private var numQuestions = 10.0
    @State private var durationMinutes = 5.0
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showFileImporter = false
    @State private var showLibraryPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section(Loc.t("source_text")) {
                    TextField(Loc.t("paste_text_here"), text: $sourceText, axis: .vertical)
                        .lineLimit(4...10)

                    Button {
                        showFileImporter = true
                    } label: {
                        Label(Loc.t("upload_pdf"), systemImage: "doc.badge.plus")
                    }

                    Button {
                        showLibraryPicker = true
                    } label: {
                        Label(Loc.t("pick_from_library"), systemImage: "books.vertical")
                    }
                }

                Section(Loc.t("quiz_settings")) {
                    Stepper(String(format: Loc.t("num_questions_format"), Int(numQuestions)), value: $numQuestions, in: 3...20, step: 1)
                    Stepper(String(format: Loc.t("duration_minutes_format"), Int(durationMinutes)), value: $durationMinutes, in: 1...30, step: 1)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }

                Section {
                    Button {
                        Task { await generateAndStart() }
                    } label: {
                        if isGenerating {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(Loc.t("start_quiz")).frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(sourceText.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
                }
            }
            .navigationTitle(Loc.t("prepare_quiz"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("cancel")) { dismiss() }
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf]) { result in
                switch result {
                case .success(let url): Task { await uploadPDF(url) }
                case .failure: errorMessage = Loc.t("error_generic")
                }
            }
            .sheet(isPresented: $showLibraryPicker) {
                LibraryPickerView { detail in
                    sourceText = detail.extractedText
                }
            }
        }
    }

    private func uploadPDF(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let filename = try await APIClient.shared.upload(fileURL: url)
            sourceText = try await APIClient.shared.extractText(filename: filename)
        } catch {
            errorMessage = Loc.t("error_generic")
        }
    }

    private func generateAndStart() async {
        isGenerating = true
        errorMessage = nil
        do {
            let raw = try await APIClient.shared.generateQuizRaw(text: sourceText, numQuestions: Int(numQuestions), lang: settings.languageCode)
            let questions = QuizParser.parse(raw)
            guard !questions.isEmpty else {
                errorMessage = Loc.t("error_generic")
                isGenerating = false
                return
            }
            onStart(questions, durationMinutes)
            dismiss()
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isGenerating = false
    }
}
