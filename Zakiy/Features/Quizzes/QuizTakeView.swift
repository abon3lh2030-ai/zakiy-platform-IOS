import SwiftUI

/// حل اختبار - طالب بس. عند الفتح: لو فيه محاولة مسلَّمة مسبقًا (attempt من
/// GET التفصيل) نروح مباشرة لشاشة النتيجة بدون /start. غير كذا ننادي /start
/// (idempotent - ما يصفّر الوقت لو رجعنا فتحنا الاختبار بمنتصف محاولة سابقة)
/// ونحسب الموعد النهائي من started_at + مدة الاختبار، مع عدّاد تنازلي حي
/// (Task.sleep كل ثانية) يسلّم تلقائيًا لما يوصل صفر حتى لو فيه أسئلة بدون
/// إجابة - يشتغل طول ما الشاشة مفتوحة بالتطبيق (بدون جدولة خلفية).
struct QuizTakeView: View {
    let quizId: String

    @State private var detail: QuizStudentDetail?
    @State private var attempt: QuizAttemptRecord?
    @State private var answers: [String: String] = [:]
    @State private var deadline: Date?
    @State private var remainingSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSubmitConfirm = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let attempt, attempt.submittedAt != nil {
                resultView(attempt)
            } else if let detail {
                takeView(detail)
            } else if let errorMessage {
                ContentUnavailableView(Loc.t("quizzes"), systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            }
        }
        .background(Color.appBackground)
        .navigationTitle(detail?.title ?? Loc.t("quizzes"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: - تحميل + بدء المحاولة

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let d = try await APIClient.shared.studentQuizDetail(id: quizId)
            detail = d
            if let existing = d.attempt, existing.submittedAt != nil {
                attempt = existing
            } else {
                let started = try await APIClient.shared.startQuiz(id: quizId)
                if !started.answers.isEmpty { answers = started.answers }
                // نطلع للوقت الفعلي من started_at لو قدرنا نفكّه، غير كذا
                // نفترض "الآن" كبداية احتياطًا (يخلي العدّاد يشتغل بأي حال
                // بدل ما يتعطّل لو صيغة الوقت اختلفت عن المتوقع)
                let startedDate = Self.parseDate(started.startedAt) ?? Date()
                deadline = startedDate.addingTimeInterval(Double(d.timeLimitMinutes * 60))
                startTimer()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                guard let deadline else { return }
                let remaining = Int(deadline.timeIntervalSinceNow.rounded(.up))
                remainingSeconds = max(0, remaining)
                if remaining <= 0 {
                    await submit(auto: true)
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - عرض الحل

    @ViewBuilder
    private func takeView(_ detail: QuizStudentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(detail.subject).font(.caption).foregroundStyle(.secondary)
                    Text(detail.title).font(.title2.weight(.bold))
                    Text(Loc.t("quiz_time_remaining_label", remainingLabel))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(remainingSeconds <= 60 ? Color.red : Color.accentColor)
                }

                ForEach(sortedQuestions(detail)) { question in
                    QuestionAnswerCard(question: question, answer: answerBinding(for: question.id))
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }

                Button {
                    showSubmitConfirm = true
                } label: {
                    if isSubmitting { ProgressView().frame(maxWidth: .infinity) }
                    else { Text(Loc.t("btn_submit_quiz")).frame(maxWidth: .infinity) }
                }
                .buttonStyle(.appPrimary)
                .disabled(isSubmitting)
            }
            .padding()
        }
        .confirmationDialog(Loc.t("quiz_submit_confirm_title"), isPresented: $showSubmitConfirm, titleVisibility: .visible) {
            Button(Loc.t("btn_submit_quiz")) { Task { await submit(auto: false) } }
            Button(Loc.t("cancel"), role: .cancel) {}
        } message: {
            Text(Loc.t("quiz_submit_confirm_message"))
        }
    }

    private func sortedQuestions(_ detail: QuizStudentDetail) -> [QuizQuestionForStudent] {
        detail.questions.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func answerBinding(for questionId: String) -> Binding<String> {
        Binding(
            get: { answers[questionId] ?? "" },
            set: { answers[questionId] = $0 }
        )
    }

    private var remainingLabel: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - تسليم (يدوي أو تلقائي عند انتهاء الوقت)

    private func submit(auto: Bool) async {
        timerTask?.cancel()
        isSubmitting = true
        errorMessage = nil
        do {
            let result = try await APIClient.shared.submitQuiz(id: quizId, answers: answers, autoSubmitted: auto)
            attempt = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    // MARK: - النتيجة

    @ViewBuilder
    private func resultView(_ attempt: QuizAttemptRecord) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: attempt.isGraded ? "checkmark.seal.fill" : "clock.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(attempt.isGraded ? Color.green : Color.orange)
                if attempt.isGraded {
                    Text(Loc.t("quiz_result_graded_heading")).font(.title2.bold())
                    Text(Loc.t("quiz_result_grade_format", attempt.grade ?? "-")).font(.title3)
                } else {
                    Text(Loc.t("quiz_awaiting_grade")).font(.title2.bold())
                    Text(attempt.autoSubmitted ? Loc.t("quiz_result_auto_submitted_message") : Loc.t("quiz_result_awaiting_message"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - تحويل نص التاريخ من الباك إند لـ Date

    private static func parseDate(_ string: String) -> Date? {
        if let d = isoFractional.date(from: string) { return d }
        if let d = isoPlain.date(from: string) { return d }
        return fallbackFormatter.date(from: string)
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let fallbackFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return f
    }()
}

// MARK: - سؤال + منطقة الإجابة عليه

private struct QuestionAnswerCard: View {
    let question: QuizQuestionForStudent
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.questionText).font(.body.weight(.medium))

            switch question.questionType {
            case "mcq":
                VStack(spacing: 8) {
                    ForEach(question.choices ?? [], id: \.self) { choice in
                        choiceRow(choice)
                    }
                }
            case "true_false":
                VStack(spacing: 8) {
                    choiceRow(Loc.t("quiz_true_label"), value: "true")
                    choiceRow(Loc.t("quiz_false_label"), value: "false")
                }
            default:
                TextEditor(text: $answer)
                    .frame(minHeight: 100)
                    .overlay(alignment: .topLeading) {
                        if answer.isEmpty {
                            Text(Loc.t("quiz_essay_answer_placeholder"))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8).padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(4)
                    .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func choiceRow(_ label: String, value: String? = nil) -> some View {
        let choiceValue = value ?? label
        Button {
            answer = choiceValue
        } label: {
            HStack {
                Text(label)
                Spacer()
                if answer == choiceValue {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(answer == choiceValue ? Color.accentColor.opacity(0.25) : Color.appBackground, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
