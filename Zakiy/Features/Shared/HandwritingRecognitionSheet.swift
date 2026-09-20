import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// محرر مشترك: يقرأ صورة/‏PDF بخدمة ذكيّ ثم يتيح تصحيح النص قبل استخدامه.
struct HandwritingRecognitionSheet: View {
    let context: String
    let onUse: (String) -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var recognizedText = ""
    @State private var selectedName = ""
    @State private var isReading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(Loc.t("handwriting_choose_photo"), systemImage: "photo")
                    }
                    Button { showFileImporter = true } label: {
                        Label(Loc.t("handwriting_choose_file"), systemImage: "doc")
                    }
                    if !selectedName.isEmpty { Text(selectedName).font(.footnote).foregroundStyle(.secondary) }
                } footer: {
                    Text(Loc.t("handwriting_supported_hint"))
                }

                if isReading {
                    HStack { ProgressView(); Text(Loc.t("handwriting_reading")) }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                if !recognizedText.isEmpty {
                    Section(Loc.t("handwriting_review")) {
                        TextEditor(text: $recognizedText).frame(minHeight: 220)
                    }
                    Section {
                        Button(Loc.t("handwriting_use")) {
                            let value = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                            onUse(value)
                            dismiss()
                        }
                        .disabled(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle(Loc.t("handwriting_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Loc.t("cancel")) { dismiss() } } }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        errorMessage = Loc.t("handwriting_failed"); return
                    }
                    await recognize(data: data, filename: "handwriting.jpg", mimeType: "image/jpeg")
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .png, .jpeg, .webP, .heic],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else {
                    if case .failure = result { errorMessage = Loc.t("handwriting_failed") }
                    return
                }
                Task {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        let mime = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.preferredMIMEType) ?? "application/pdf"
                        await recognize(data: data, filename: url.lastPathComponent, mimeType: mime)
                    } catch { errorMessage = error.localizedDescription }
                }
            }
        }
    }

    @MainActor
    private func recognize(data: Data, filename: String, mimeType: String) async {
        guard data.count <= 15 * 1024 * 1024 else { errorMessage = Loc.t("handwriting_too_large"); return }
        selectedName = filename
        isReading = true
        errorMessage = nil
        recognizedText = ""
        do {
            recognizedText = try await APIClient.shared.recognizeHandwriting(
                data: data, filename: filename, mimeType: mimeType, context: context, lang: settings.languageCode
            )
        } catch { errorMessage = error.localizedDescription }
        isReading = false
    }
}
