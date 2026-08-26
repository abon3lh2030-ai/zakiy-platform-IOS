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

/// مدرستي: اختصار لموقع مدرستي الرسمي (بدون أي تكامل بيانات - ما فيه API
/// عام لمدرستي) + أدوات ذكيّ بالذكاء الاصطناعي للمعلم والطالب. متاحة لأي
/// حساب مسجّل دخول بدون قيد دور - نفس سلوك زر مدرستي بالسايدبار بالموقع.
struct MadrasatiHubView: View {
    @State private var showOfficialSite = false
    @State private var lessonPreps: [LessonPrepSummary] = []
    @State private var homeworkSessions: [HomeworkHelpSummary] = []
    @State private var studyPlans: [StudyPlanSummary] = []
    @State private var teacherListError: String?
    @State private var studentListError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(Loc.t("madrasati_desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                officialLinkCard

                teacherToolsSection

                Divider()

                studentToolsSection
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

    private var teacherToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Loc.t("teacher_tools_heading")).font(.headline)

            NavigationLink(value: MadrasatiRoute.lessonPrepNew) {
                Text(Loc.t("btn_new_lesson_prep")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.appPrimary)

            HStack(spacing: 10) {
                NavigationLink(value: MadrasatiRoute.enrichment) {
                    Text(Loc.t("btn_open_enrichment")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                NavigationLink(value: MadrasatiRoute.resultsAnalysis) {
                    Text(Loc.t("btn_open_results_analysis")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
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

    private var studentToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Loc.t("student_tools_heading")).font(.headline)

            HStack(spacing: 10) {
                NavigationLink(value: MadrasatiRoute.homeworkHelpNew) {
                    Text(Loc.t("btn_new_homework_help")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.appPrimary)
                NavigationLink(value: MadrasatiRoute.studyPlanNew) {
                    Text(Loc.t("btn_new_study_plan")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
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
