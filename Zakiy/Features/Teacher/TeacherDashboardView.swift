import SwiftUI

/// لوحة المعلم: قد يدرّس أكثر من فصل - محدد فصل أعلى اللوحة يفلتر الأقسام
/// اللي تحته، وزر "ابدأ درس مباشر" ينشئ غرفة كلاس مربوطة بالفصل المختار
/// مباشرة (يسجّل حضور تلقائي) بإعادة استخدام نظام الغرف/السبورة/الصوت
/// الموجود بالكامل. الأقسام (الطلاب/الأداء/جدولي/الحضور/المكتبة) قائمة
/// عناصر تُفتح كل وحدة بصفحتها لحالها (بدل تبويبات مقسّمة بسطر وحد ضيق) -
/// نفس أسلوب شاشة الإعدادات، يوسّع بسهولة لو زدنا أقسام بعدين.
struct TeacherDashboardView: View {
    private struct LiveClassDestination: Identifiable, Hashable {
        let roomCode: String
        var id: String { roomCode }
    }

    @State private var classes: [SchoolClass] = []
    @State private var selectedClassId: String?
    @State private var isStartingClass = false
    @State private var startError: String?
    @State private var liveClassDestination: LiveClassDestination?

    var body: some View {
        List {
            Section {
                if !classes.isEmpty {
                    Picker(Loc.t("opt_all_my_classes"), selection: $selectedClassId) {
                        Text(Loc.t("opt_all_my_classes")).tag(String?.none)
                        ForEach(classes) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                Button {
                    Task { await startLiveClass() }
                } label: {
                    if isStartingClass {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(Loc.t("btn_start_live_class")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStartingClass || selectedClassId == nil)
                if let startError {
                    Text(startError).font(.footnote).foregroundStyle(.red)
                }
            }

            Section {
                NavigationLink { TeacherRosterView(selectedClassId: $selectedClassId) } label: {
                    DashboardMenuRow(icon: "person.3.fill", tint: .blue, title: Loc.t("tab_roster"))
                }
                NavigationLink { TeacherPerformanceView(selectedClassId: selectedClassId) } label: {
                    DashboardMenuRow(icon: "chart.bar.fill", tint: .purple, title: Loc.t("tab_performance"))
                }
                NavigationLink { TeacherScheduleView() } label: {
                    DashboardMenuRow(icon: "calendar", tint: .orange, title: Loc.t("tab_schedule"))
                }
                NavigationLink { TeacherAttendanceView(selectedClassId: selectedClassId) } label: {
                    DashboardMenuRow(icon: "checklist", tint: .green, title: Loc.t("tab_attendance"))
                }
                // مكتبة المعلم الشخصية (يرفع ويحفظ كتبه/ملازمه) - نفس شاشة
                // مكتبة الطلاب بالضبط، بس مدموجة هنا لأن حساب مؤسسي ما يوصل
                // MainTabView العادي إطلاقًا (لوحته تحل محله بالكامل)
                NavigationLink { LibraryListView() } label: {
                    DashboardMenuRow(icon: "books.vertical.fill", tint: .indigo, title: Loc.t("tab_library"))
                }
                // دفتر الواجبات - معلم/طالب بس، نفس سبب دمج المكتبة هنا
                // (حساب مؤسسي ما يوصل MainTabView/SettingsView العادي)
                NavigationLink { AssignmentsListView() } label: {
                    DashboardMenuRow(icon: "doc.text.fill", tint: .pink, title: Loc.t("assignments"))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(Loc.t("teacher_dash_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { RoleDashboardToolbar() }
        .navigationDestination(item: $liveClassDestination) { dest in
            RoomContainerView(roomCode: dest.roomCode, roomType: "classroom", isCreator: true)
        }
        .task { await loadClasses() }
    }

    private func loadClasses() async {
        let roster = try? await APIClient.shared.teacherRoster()
        classes = roster?.classes ?? []
        if selectedClassId == nil { selectedClassId = classes.first?.id }
    }

    /// نفس مسار `APIClient.createRoom` المستخدم بلوحة الاستهلاك العادية، بس
    /// بدون بوابة الاشتراك/الحد المجاني (`UsageLimiter`/`PaywallView`) - حساب
    /// مؤسسي، مو مستخدم فردي بباقة مجانية.
    private func startLiveClass() async {
        guard let classId = selectedClassId else { return }
        startError = nil
        isStartingClass = true
        do {
            let code = try await APIClient.shared.createRoom(roomType: "classroom", classId: classId)
            liveClassDestination = LiveClassDestination(roomCode: code)
        } catch {
            startError = Loc.t("error_generic")
        }
        isStartingClass = false
    }
}
