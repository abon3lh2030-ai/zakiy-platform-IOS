import SwiftUI

/// لوحة المعلم: قد يدرّس أكثر من فصل - محدد فصل أعلى اللوحة يفلتر كل التبويبات،
/// وزر "ابدأ درس مباشر" ينشئ غرفة كلاس مربوطة بالفصل المختار مباشرة (يسجّل
/// حضور تلقائي) بإعادة استخدام نظام الغرف/السبورة/الصوت الموجود بالكامل.
struct TeacherDashboardView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case roster, performance, schedule, attendance
        var id: String { rawValue }
        var titleKey: String {
            switch self {
            case .roster: "tab_roster"
            case .performance: "tab_performance"
            case .schedule: "tab_schedule"
            case .attendance: "tab_attendance"
            }
        }
    }

    private struct LiveClassDestination: Identifiable, Hashable {
        let roomCode: String
        var id: String { roomCode }
    }

    @State private var tab: Tab = .roster
    @State private var classes: [SchoolClass] = []
    @State private var selectedClassId: String?
    @State private var isStartingClass = false
    @State private var startError: String?
    @State private var liveClassDestination: LiveClassDestination?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
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
            .padding(.horizontal)
            .padding(.top, 8)

            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(Loc.t(t.titleKey)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                switch tab {
                case .roster: TeacherRosterView(selectedClassId: $selectedClassId)
                case .performance: TeacherPerformanceView(selectedClassId: selectedClassId)
                case .schedule: TeacherScheduleView()
                case .attendance: TeacherAttendanceView(selectedClassId: selectedClassId)
                }
            }
        }
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
