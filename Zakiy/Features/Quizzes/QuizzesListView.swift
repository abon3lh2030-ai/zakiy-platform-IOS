import SwiftUI

/// الاختبارات - معلم أو طالب بس (نفس تقييد دفتر الواجبات، الباك إند يرفض أي
/// حساب فردي). معلم يشوف اختباراته (مسودة/منشور + عدد المسلّمين) وينشئ
/// جديد، طالب يشوف اختباراته المتاحة وحالتها. كل اختبار يفتح بصفحته الخاصة -
/// تفصيل/تصحيح للمعلم (QuizDetailView) أو حل/نتيجة للطالب (QuizTakeView).
struct QuizzesListView: View {
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var quizzes: [QuizSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var openedQuiz: QuizRoute?

    private var isTeacher: Bool { auth.role == "teacher" }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(Loc.t("quizzes"), systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if quizzes.isEmpty {
                ContentUnavailableView(Loc.t("quizzes"), systemImage: "list.bullet.clipboard", description: Text(Loc.t("quizzes_empty")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(quizzes) { quiz in
                    Button { openedQuiz = QuizRoute(id: quiz.id) } label: {
                        QuizRow(quiz: quiz, isTeacher: isTeacher)
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("quizzes_heading"))
        .toolbar {
            if isTeacher {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateSheet = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showCreateSheet) {
            QuizCreateView { await load() }
        }
        .navigationDestination(item: $openedQuiz) { route in
            if isTeacher {
                QuizDetailView(quizId: route.id)
            } else {
                QuizTakeView(quizId: route.id)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            quizzes = isTeacher ? try await APIClient.shared.teacherQuizzes() : try await APIClient.shared.studentQuizzes()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct QuizRow: View {
    let quiz: QuizSummary
    let isTeacher: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(quiz.title).font(.body.weight(.medium))
                Text(quiz.subject).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isTeacher {
            if quiz.isPublished {
                let done = quiz.submittedCount ?? 0
                let total = quiz.totalCount ?? 0
                Text(Loc.t("quiz_submitted_count", done, total))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(done >= total && total > 0 ? Color.green : Color.orange)
            } else {
                Text(Loc.t("quiz_status_draft"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        } else if quiz.submitted == true {
            if quiz.isGraded == true, let grade = quiz.grade {
                Text(grade).font(.caption.weight(.semibold)).foregroundStyle(Color.green)
            } else {
                Text(Loc.t("quiz_awaiting_grade")).font(.caption.weight(.semibold)).foregroundStyle(Color.orange)
            }
        } else {
            Text(Loc.t("quiz_status_not_taken")).font(.caption.weight(.semibold)).foregroundStyle(Color.orange)
        }
    }
}

/// غلاف Identifiable بسيط لـ navigationDestination(item:) - نفس أسلوب
/// AssignmentRoute/NoteRoute المتبع بباقي الميزات
struct QuizRoute: Identifiable, Hashable {
    let id: String
}
