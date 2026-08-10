import SwiftUI

struct SchoolBulkAddView: View {
    @State private var classes: [SchoolClass] = []
    @State private var selectedClassId: String?
    @State private var namesText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var result: [GeneratedStudent] = []
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        List {
            Section(Loc.t("tab_bulk_students")) {
                Text(Loc.t("bulk_add_desc")).font(.footnote).foregroundStyle(.secondary)

                if classes.isEmpty {
                    Text(Loc.t("opt_create_class_first")).foregroundStyle(.secondary)
                } else {
                    Picker(Loc.t("th_class_name"), selection: $selectedClassId) {
                        ForEach(classes) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
                }

                TextField(Loc.t("ph_bulk_names"), text: $namesText, axis: .vertical)
                    .lineLimit(6...12)

                Button {
                    Task { await bulkAdd() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("btn_bulk_add")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving || selectedClassId == nil || namesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
            }

            if !result.isEmpty {
                Section(Loc.t("bulk_result_heading")) {
                    ForEach(result) { student in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(student.name).font(.subheadline.bold())
                            Text("\(student.username) — \(student.password)").font(.caption.monospaced())
                        }
                    }
                    Button(Loc.t("btn_export_csv")) {
                        shareURL = CSVExporter.makeStudentsCSV(result)
                        showShareSheet = shareURL != nil
                    }
                }
            }
        }
        .task { await loadClasses() }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
    }

    private func loadClasses() async {
        classes = (try? await APIClient.shared.schoolClasses()) ?? []
        if selectedClassId == nil { selectedClassId = classes.first?.id }
    }

    private func bulkAdd() async {
        guard let classId = selectedClassId else { return }
        errorMessage = nil
        isSaving = true
        let names = namesText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        do {
            result = try await APIClient.shared.schoolBulkAddStudents(classId: classId, names: names)
            namesText = ""
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isSaving = false
    }
}
