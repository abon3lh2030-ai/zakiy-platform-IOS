import SwiftUI

/// كشف الدرجات - معلم بس (الباك إند يرفض أي حساب فردي عبر require_role).
/// المشاركة والمهام الأدائية تُعدَّل يدويًا لكل طالب بزر حفظ مستقل لكل صف،
/// بينما الواجبات/الاختبارات محسوبة تلقائيًا بالباك إند من تصحيح المعلم لها
/// (تُعرض بس، ما تُعدَّل هنا)، والمجموع محسوب سيرفريًا دايمًا - ما فيه أي
/// طريقة بالواجهة تعدّله مباشرة (نفس منطق gradesheet.html/27-gradesheet.js
/// بالموقع بالضبط).
struct GradesheetView: View {
    @State private var classes: [SchoolClass] = []
    @State private var selectedClassId: String?
    @State private var rows: [GradesheetStudentRow] = []
    @State private var isLoadingClasses = true
    @State private var isLoadingRows = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoadingClasses {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if classes.isEmpty {
                ContentUnavailableView(
                    Loc.t("nav_gradesheet"),
                    systemImage: "list.bullet.clipboard",
                    description: Text(Loc.t("gradesheet_no_classes"))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        Picker(Loc.t("gradesheet_class_label"), selection: $selectedClassId) {
                            ForEach(classes) { c in Text(c.name).tag(Optional(c.id)) }
                        }
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(.red).font(.footnote)
                        }
                    }

                    Section {
                        if isLoadingRows {
                            ProgressView(Loc.t("loading")).frame(maxWidth: .infinity)
                        } else if rows.isEmpty {
                            Text(Loc.t("gradesheet_empty")).foregroundStyle(.secondary)
                        } else {
                            ForEach(rows) { row in
                                GradesheetRowView(row: row, onSave: saveRow)
                                    .listRowInsets(EdgeInsets())
                                    .padding(.vertical, 6)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("gradesheet_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadClasses() }
        .task(id: selectedClassId) { await loadRows() }
        .refreshable { await loadRows() }
    }

    private func loadClasses() async {
        isLoadingClasses = true
        let roster = try? await APIClient.shared.teacherRoster()
        classes = roster?.classes ?? []
        if selectedClassId == nil { selectedClassId = classes.first?.id }
        isLoadingClasses = false
    }

    private func loadRows() async {
        guard let selectedClassId else { return }
        isLoadingRows = true
        errorMessage = nil
        do {
            rows = try await APIClient.shared.teacherGradesheet(classId: selectedClassId)
        } catch {
            rows = []
            errorMessage = error.localizedDescription
        }
        isLoadingRows = false
    }

    /// يحفظ صف طالب وحد ثم يعيد جلب الكشف كامل عشان يحدّث `total` المحسوب
    /// سيرفريًا (نفس أسلوب `loadGradesheetTable` بالموقع بالضبط) - يرجّع
    /// نجاح/فشل العملية عشان الصف يوقف مؤشر التحميل عنده.
    private func saveRow(studentId: String, participation: Double, performanceTasks: Double) async -> Bool {
        guard let selectedClassId else { return false }
        errorMessage = nil
        do {
            try await APIClient.shared.updateGradesheetRow(
                studentId: studentId, classId: selectedClassId,
                participation: participation, performanceTasks: performanceTasks
            )
            rows = try await APIClient.shared.teacherGradesheet(classId: selectedClassId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

/// صف طالب وحد بكشف الدرجات - اسم + مشاركة/مهام أدائية قابلتين للتعديل +
/// زر حفظ خاص بيه، وتحتهم الواجبات/الاختبارات/المجموع للعرض بس (بدون تعديل).
private struct GradesheetRowView: View {
    let row: GradesheetStudentRow
    var onSave: (String, Double, Double) async -> Bool

    @State private var participationText: String
    @State private var performanceTasksText: String
    @State private var isSaving = false

    init(row: GradesheetStudentRow, onSave: @escaping (String, Double, Double) async -> Bool) {
        self.row = row
        self.onSave = onSave
        _participationText = State(initialValue: Self.format(row.participation))
        _performanceTasksText = State(initialValue: Self.format(row.performanceTasks))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(row.fullName ?? row.username).font(.subheadline.weight(.semibold))

            HStack(alignment: .bottom, spacing: 10) {
                labeledField(Loc.t("th_participation"), text: $participationText)
                labeledField(Loc.t("th_performance_tasks"), text: $performanceTasksText)
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView() } else { Text(Loc.t("save")) }
                }
                .font(.caption)
                .disabled(isSaving)
            }

            Divider()

            HStack(alignment: .top) {
                gradeLabel(Loc.t("th_assignments_avg"), value: row.assignmentsAvg, count: row.assignmentsCount)
                Spacer()
                gradeLabel(Loc.t("th_quizzes_avg"), value: row.quizzesAvg, count: row.quizzesCount)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Loc.t("th_total")).font(.caption2).foregroundStyle(.secondary)
                    Text(Self.format(row.total)).font(.subheadline.weight(.bold))
                }
            }
        }
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
        }
    }

    private func gradeLabel(_ title: String, value: Double?, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value.map { "\(Self.format($0)) (\(count))" } ?? "—").font(.subheadline)
        }
    }

    private func save() async {
        guard let participation = Self.parse(participationText), let performanceTasks = Self.parse(performanceTasksText) else { return }
        isSaving = true
        _ = await onSave(row.userId, participation, performanceTasks)
        isSaving = false
    }

    /// نص فاضي يُعامل كصفر (نفس معاملة الموقع بالضبط بـ wireGradesheetRowEvents)
    private static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        return Double(trimmed)
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.2f", value)
    }
}
