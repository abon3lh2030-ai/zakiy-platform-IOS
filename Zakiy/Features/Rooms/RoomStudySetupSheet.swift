import SwiftUI
import UniformTypeIdentifiers

/// Sheet the host uses to prepare a quiz for the room: pick a source (paste, upload, or a saved
/// library book — "any book"), generate a summary, optionally share it with the room, then
/// generate and start the quiz. A summary is required before starting — this both matches the
/// old flow and gives students something to review first.
struct RoomStudySetupSheet: View {
    @Bindable var socket: RoomSocketManager
    let onStart: ([QuizQuestion], Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var sourceText = ""
    @State private var summary: String?
    @State private var isSummarySharedWithRoom = false
    @State private var numQuestions = 10.0
    @State private var durationMinutes = 5.0
    @State private var isGeneratingSummary = false
    @State private var isGeneratingQuiz = false
    @State private var errorMessage: String?
    @State private var showFileImporter = false
    @State private var showLibraryPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section(Loc.t("source_text")) {
                    TextField(Loc.t("paste_text_here"), text: $sourceText, axis: .vertical)
                        .lineLimit(4...10)
                        .onChange(of: sourceText) { summary = nil; isSummarySharedWithRoom = false }

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

                Section(Loc.t("shared_summary")) {
                    if let summary {
                        Text(summary).font(.footnote).foregroundStyle(.secondary).lineLimit(6)

                        Toggle(Loc.t("share_summary_with_room"), isOn: Binding(
                            get: { isSummarySharedWithRoom },
                            set: { newValue in
                                isSummarySharedWithRoom = newValue
                                if newValue { socket.shareSummary(summary) }
                            }
                        ))
                    } else {
                        Button {
                            Task { await generateSummary() }
                        } label: {
                            if isGeneratingSummary {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text(Loc.t("generate_summary")).frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(sourceText.trimmingCharacters(in: .whitespaces).isEmpty || isGeneratingSummary)

                        Text(Loc.t("summary_required_hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(Loc.t("quiz_settings")) {
                    Stepper(String(format: Loc.t("num_questions_format"), Int(numQuestions)), value: $numQuestions, in: 5...20, step: 1)
                    Stepper(String(format: Loc.t("duration_minutes_format"), Int(durationMinutes)), value: $durationMinutes, in: 1...30, step: 1)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }

                Section {
                    Button {
                        Task { await generateQuizAndStart() }
                    } label: {
                        if isGeneratingQuiz {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(Loc.t("start_quiz")).frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(summary == nil || isGeneratingQuiz)
                }
            }
            .navigationTitle(Loc.t("start_study_button"))
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

    private func generateSummary() async {
        isGeneratingSummary = true
        errorMessage = nil
        do {
            summary = try await APIClient.shared.summarize(text: sourceText, lang: settings.languageCode)
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isGeneratingSummary = false
    }

    private func generateQuizAndStart() async {
        guard summary != nil else { return }
        isGeneratingQuiz = true
        errorMessage = nil
        do {
            let questions = try await APIClient.shared.generateQuiz(text: sourceText, numQuestions: Int(numQuestions), lang: settings.languageCode)
            guard !questions.isEmpty else {
                errorMessage = Loc.t("error_generic")
                isGeneratingQuiz = false
                return
            }
            onStart(questions, durationMinutes)
            dismiss()
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isGeneratingQuiz = false
    }
}
