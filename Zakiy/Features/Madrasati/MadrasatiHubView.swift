import SwiftUI
import SafariServices

/// كل وجهات مدرستي بمكان واحد - تحضير/مساعد واجب/خطة مذاكرة يفرّقون بين
/// "جديد" و"عرض عنصر محفوظ" بمعرّف اختياري، الباقي (إثراء/تحليل نتائج)
/// أدوات توليد لحظي بدون حفظ فما تحتاج معرّف إطلاقًا.
enum MadrasatiRoute: Hashable {
    case lessonPrepNew
    case lessonPrepDetail(String)
    case enrichment
    case resultsAnalysis
    case homeworkHelpNew
    case homeworkHelpDetail(String)
    case studyPlanNew
    case studyPlanDetail(String)
}

/// مدرستي: قسمين واضحين (واجهة طالب/واجهة معلم)، كل قسم شبكة بطاقات تجمع
/// اختصارات مدرستي الرسمية (بدون أي تكامل بيانات - تفتح Safari مضمّن بس) مع
/// ميزات ذكيّ الموجودة فعلًا (٥ أدوات ذكاء اصطناعي مستقلة + الواجبات/
/// الاختبارات/المكتبة/المساعد الذكي/جدولي المؤسسية). نفس تصميم الموقع بعد
/// إعادة تصميمه (راجع madrasati-hub.html + 28-madrasati.js + 03-auth.js
/// بمشروع الموقع). القسم الظاهر افتراضيًا يتحدد حسب دور الحساب - أدوات
/// ذكيّ الخمسة نفسها تبقى متاحة لأي حساب مسجّل دخول بدون قيد دور.
struct MadrasatiHubView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var showOfficialSite = false
    @State private var lessonPreps: [LessonPrepSummary] = []
    @State private var homeworkSessions: [HomeworkHelpSummary] = []
    @State private var studyPlans: [StudyPlanSummary] = []
    @State private var teacherListError: String?
    @State private var studentListError: String?

    private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    // نفس شروط ظهور بطاقات "الواجبات/الاختبارات" المكررة داخل مدرستي بلوحتي
    // المعلم/الطالب المؤسسيتين بالضبط - اختصارات مؤسسية بس تحتاج فصل/مدرسة فعلية
    private var isInstStudent: Bool { auth.role == "student" }
    private var isInstTeacher: Bool { auth.role == "teacher" }

    // قسم "واجهة المعلم" أو "واجهة الطالب" - معلم مؤسسي أو حساب فردي اختار
    // "معلم" وقت التسجيل يشوف قسم المعلم بس، إداري المدرسة (أو مدير المنصة)
    // يشوف الاثنين (يشرف على الطرفين)، وأي شي ثاني (طالب مؤسسي أو فردي عادي/
    // متخرج - المتخرج يُعامل كحساب فردي عادي) يشوف قسم الطالب بس. نفس منطق
    // isMadrasatiTeacher/isMadrasatiAdmin بموقع الويب (03-auth.js) بالضبط.
    private var isMadrasatiTeacherPersona: Bool {
        isInstTeacher || (auth.role == nil && auth.educationLevel == "معلم")
    }
    // "admin" (مدير منصة ذكيّ نفسها) ما له مقابل بأدوار الموقع - أقرب معنى له
    // إشراف على الطرفين زي إداري المدرسة، فنعامله بنفس الشي بدل ما نخفي عنه
    // قسم كامل بدون سبب
    private var isMadrasatiAdmin: Bool {
        auth.role == "school_admin" || auth.role == "school_administration" || auth.role == "admin"
    }
    private var showTeacherSection: Bool { isMadrasatiTeacherPersona || isMadrasatiAdmin }
    private var showStudentSection: Bool { !isMadrasatiTeacherPersona || isMadrasatiAdmin }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(Loc.t("madrasati_desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if showTeacherSection { teacherSection }
                if showTeacherSection && showStudentSection { Divider() }
                if showStudentSection { studentSection }

                officialLinkCard
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("madrasati_heading"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadLists() }
        .refreshable { await loadLists() }
        .sheet(isPresented: $showOfficialSite) {
            SafariView(url: URL(string: "https://schools.madrasati.sa")!)
        }
        .navigationDestination(for: MadrasatiRoute.self) { route in
            switch route {
            case .lessonPrepNew:
                LessonPrepView(existingId: nil) { await loadLessonPreps() }
            case .lessonPrepDetail(let id):
                LessonPrepView(existingId: id) { await loadLessonPreps() }
            case .enrichment:
                EnrichmentView()
            case .resultsAnalysis:
                ResultsAnalysisView()
            case .homeworkHelpNew:
                HomeworkHelpView(existingId: nil) { await loadHomeworkHelp() }
            case .homeworkHelpDetail(let id):
                HomeworkHelpView(existingId: id) { await loadHomeworkHelp() }
            case .studyPlanNew:
                StudyPlanView(existingId: nil) { await loadStudyPlans() }
            case .studyPlanDetail(let id):
                StudyPlanView(existingId: id) { await loadStudyPlans() }
            }
        }
    }

    private var officialLinkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.t("madrasati_link_desc"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showOfficialSite = true
            } label: {
                Text(Loc.t("btn_open_madrasati")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.appPrimary)
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - واجهة المعلم

    private var teacherSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Loc.t("teacher_interface_heading")).font(.headline)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                // ⚠️ بطاقات "مدرستي" الأربع تحت مؤقتًا كلها تفتح الصفحة الرئيسية
                // العامة (schools.madrasati.sa) - لازم تُستبدل لاحقًا بالرابط
                // المباشر الصحيح لكل صفحة فرعية (إدارة الواجبات/رصد الدرجات/
                // جدول الحصص/تسجيل الحضور) بمجرد ما تتوفر (نفس مؤقت الموقع بالضبط)
                madrasatiExternalCard(icon: "📤", labelKey: "md_manage_assignments")
                madrasatiExternalCard(icon: "✏️", labelKey: "md_record_grades")
                madrasatiExternalCard(icon: "🗓️", labelKey: "md_class_schedule")
                madrasatiExternalCard(icon: "✅", labelKey: "md_record_attendance")

                if isInstTeacher {
                    NavigationLink { AssignmentsListView() } label: {
                        MadrasatiLinkCard(icon: "📚", label: Loc.t("assignments"), badge: .zakiy)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { QuizzesListView() } label: {
                        MadrasatiLinkCard(icon: "📝", label: Loc.t("quizzes"), badge: .zakiy)
                    }
                    .buttonStyle(.plain)
                    // كشف الدرجات - نفس بطاقة gradesheetBtn/mdTeacherGradesheetBtn
                    // بالموقع بالضبط (أيقونة 📋 + مفتاح nav_gradesheet)
                    NavigationLink { GradesheetView() } label: {
                        MadrasatiLinkCard(icon: "📋", label: Loc.t("nav_gradesheet"), badge: .zakiy)
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink(value: MadrasatiRoute.lessonPrepNew) {
                    MadrasatiLinkCard(icon: "🧠", label: Loc.t("md_lesson_prep_label"), badge: .zakiy)
                }
                NavigationLink(value: MadrasatiRoute.enrichment) {
                    MadrasatiLinkCard(icon: "🌟", label: Loc.t("md_enrichment_label"), badge: .zakiy)
                }
                NavigationLink(value: MadrasatiRoute.resultsAnalysis) {
                    MadrasatiLinkCard(icon: "📊", label: Loc.t("md_results_analysis_label"), badge: .zakiy)
                }
            }

            Text(Loc.t("saved_lesson_preps_heading"))
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)

            if lessonPreps.isEmpty {
                Text(Loc.t("lesson_prep_empty")).font(.footnote).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(lessonPreps) { prep in
                        NavigationLink(value: MadrasatiRoute.lessonPrepDetail(prep.id)) {
                            MadrasatiItemRow(
                                title: prep.lessonTitle,
                                subtitle: [prep.subject, prep.gradeLevel, prep.unit].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let teacherListError {
                Text(teacherListError).foregroundStyle(.red).font(.footnote)
            }
        }
    }

    // MARK: - واجهة الطالب

    private var studentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Loc.t("student_interface_heading")).font(.headline)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                // ⚠️ نفس ملاحظة بطاقات "مدرستي" بقسم المعلم أعلاه - الأربع
                // تحت مؤقتًا بنفس رابط schools.madrasati.sa لحد ما تتوفر
                // الروابط المباشرة لكل صفحة فرعية
                madrasatiExternalCard(icon: "📤", labelKey: "md_submit_assignments")
                madrasatiExternalCard(icon: "📊", labelKey: "md_view_grades")
                madrasatiExternalCard(icon: "🗓️", labelKey: "md_study_schedule")
                madrasatiExternalCard(icon: "✅", labelKey: "md_attendance")

                if isInstStudent {
                    NavigationLink { AssignmentsListView() } label: {
                        MadrasatiLinkCard(icon: "📚", label: Loc.t("assignments"), badge: .zakiy)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { QuizzesListView() } label: {
                        MadrasatiLinkCard(icon: "📝", label: Loc.t("quizzes"), badge: .zakiy)
                    }
                    .buttonStyle(.plain)
                    // "جدولي" محتاج فصل فعلي مربوط بالحساب - نفس شرط تبويب جدولي
                    // بـ MainTabView بالضبط (role == student && classId != nil)
                    if auth.classId != nil {
                        NavigationLink { StudentScheduleView() } label: {
                            MadrasatiLinkCard(icon: "🗓️", label: Loc.t("my_schedule"), badge: .zakiy)
                        }
                        .buttonStyle(.plain)
                    }
                }

                NavigationLink { LibraryListView() } label: {
                    MadrasatiLinkCard(icon: "📚", label: Loc.t("library"), badge: .zakiy)
                }
                .buttonStyle(.plain)
                NavigationLink { AIConversationsListView() } label: {
                    MadrasatiLinkCard(icon: "🤖", label: Loc.t("ai_assistant"), badge: .zakiy)
                }
                .buttonStyle(.plain)
                NavigationLink(value: MadrasatiRoute.homeworkHelpNew) {
                    MadrasatiLinkCard(icon: "📚", label: Loc.t("md_homework_help_label"), badge: .zakiy)
                }
                NavigationLink(value: MadrasatiRoute.studyPlanNew) {
                    MadrasatiLinkCard(icon: "🗓️", label: Loc.t("md_study_plan_label"), badge: .zakiy)
                }
            }

            Text(Loc.t("saved_homework_help_heading"))
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)

            if homeworkSessions.isEmpty {
                Text(Loc.t("homework_help_empty")).font(.footnote).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(homeworkSessions) { session in
                        NavigationLink(value: MadrasatiRoute.homeworkHelpDetail(session.id)) {
                            MadrasatiItemRow(title: session.topic, subtitle: "\(session.subject) · \(session.gradeLevel)")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text(Loc.t("saved_study_plans_heading"))
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)

            if studyPlans.isEmpty {
                Text(Loc.t("study_plan_empty")).font(.footnote).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(studyPlans) { plan in
                        NavigationLink(value: MadrasatiRoute.studyPlanDetail(plan.id)) {
                            MadrasatiItemRow(title: plan.subjects, subtitle: plan.examDate ?? "")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let studentListError {
                Text(studentListError).foregroundStyle(.red).font(.footnote)
            }
        }
    }

    /// بطاقة اختصار مدرستي الرسمية - تفتح Safari مضمّن على نفس الرابط المؤقت
    /// بغض النظر عن أي بطاقة ضُغطت (راجع الملاحظة أعلى كل قسم)
    private func madrasatiExternalCard(icon: String, labelKey: String) -> some View {
        Button {
            showOfficialSite = true
        } label: {
            MadrasatiLinkCard(icon: icon, label: Loc.t(labelKey), badge: .madrasati)
        }
        .buttonStyle(.plain)
    }

    private func loadLists() async {
        async let lessonPrepsLoad: Void = loadLessonPreps()
        async let homeworkLoad: Void = loadHomeworkHelp()
        async let studyPlansLoad: Void = loadStudyPlans()
        _ = await (lessonPrepsLoad, homeworkLoad, studyPlansLoad)
    }

    private func loadLessonPreps() async {
        do {
            lessonPreps = try await APIClient.shared.lessonPreps()
            teacherListError = nil
        } catch {
            teacherListError = error.localizedDescription
        }
    }

    private func loadHomeworkHelp() async {
        do {
            homeworkSessions = try await APIClient.shared.homeworkHelpSessions()
            studentListError = nil
        } catch {
            studentListError = error.localizedDescription
        }
    }

    private func loadStudyPlans() async {
        do {
            studyPlans = try await APIClient.shared.studyPlans()
            studentListError = nil
        } catch {
            studentListError = error.localizedDescription
        }
    }
}

/// بطاقة شبكة موحّدة لكل اختصارات مدرستي/ذكيّ داخل شاشة "مدرستي" - أيقونة
/// + عنوان + شارة صغيرة بالزاوية تفرّق مصدر البطاقة (مدرستي الرسمية مقابل
/// ميزة ذكيّ). نفس نمط بطاقات الميزات الحالية بالتطبيق (خلفية appCard،
/// انحناء 14، ظل خفيف) - راجع HomeActionCard/StudyOptionCard.
struct MadrasatiLinkCard: View {
    enum Badge { case madrasati, zakiy }

    let icon: String
    let label: String
    let badge: Badge

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(icon).font(.title2)
                Spacer(minLength: 6)
                badgeView
            }
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    @ViewBuilder
    private var badgeView: some View {
        switch badge {
        case .madrasati:
            Text(Loc.t("md_badge_madrasati"))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.18), in: Capsule())
                .foregroundStyle(.secondary)
        case .zakiy:
            Text(Loc.t("md_badge_zakiy"))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.22), in: Capsule())
                .foregroundStyle(Color.accentColor)
        }
    }
}

/// صف عنصر محفوظ موحّد (تحضير/جلسة مساعد واجب/خطة مذاكرة) - نفس أسلوب
/// بطاقة الواجب/الاختبار المتبع بباقي الميزات.
struct MadrasatiItemRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.body.weight(.medium))
            if !subtitle.isEmpty {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// يفتح موقع مدرستي الرسمي داخل تبويب Safari مضمّن - اختصار خارجي بحت،
/// ذكيّ ما يلمس ولا يشوف أي بيانات حساب المستخدم هناك إطلاقًا.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
