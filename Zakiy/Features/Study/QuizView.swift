import SwiftUI

struct QuizView: View {
    let sourceText: String

    @Environment(AppSettings.self) private var settings

    @State private var questions: [QuizQuestion] = []
    @State private var isLoading = true
    @State private var currentIndex = 0
    @State private var selectedOption: Int?
    @State private var score = 0
    @State private var isFinished = false
    @State private var startedAt = Date()
    @State private var wrongTopics: [String] = []

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("generating_quiz")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if questions.isEmpty {
                ContentUnavailableView(Loc.t("generate_quiz"), systemImage: "questionmark.circle", description: Text(Loc.t("error_generic")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isFinished {
                resultView
            } else {
                questionView
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("generate_quiz"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            startedAt = Date()
            questions = (try? await APIClient.shared.generateQuiz(text: sourceText, numQuestions: 10, lang: settings.languageCode)) ?? []
            isLoading = false
        }
    }

    private var questionView: some View {
        let question = questions[currentIndex]
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(format: Loc.t("question_number"), currentIndex + 1, questions.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(question.question)
                    .font(.title3.bold())

                VStack(spacing: 10) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        Button {
                            selectedOption = index
                        } label: {
                            HStack {
                                Text(option)
                                Spacer()
                                if selectedOption == index {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedOption == index ? Color.accentColor.opacity(0.25) : Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    submitAnswer(for: question)
                } label: {
                    Text(currentIndex == questions.count - 1 ? Loc.t("finish") : Loc.t("next_question"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.appPrimary)
                .disabled(selectedOption == nil)
            }
            .padding()
        }
    }

    private var resultView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)
            Text(String(format: Loc.t("your_score_format"), score, questions.count))
                .font(.title.bold())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await recordAttempt() }
    }

    private func submitAnswer(for question: QuizQuestion) {
        guard let selectedOption else { return }
        let chosenText = question.options[selectedOption]
        if chosenText == question.correctAnswer {
            score += 1
        } else {
            wrongTopics.append(question.question)
        }
        self.selectedOption = nil
        if currentIndex == questions.count - 1 {
            isFinished = true
        } else {
            currentIndex += 1
        }
    }

    private func recordAttempt() async {
        let timeTaken = Int(Date().timeIntervalSince(startedAt))
        try? await APIClient.shared.recordQuizAttempt(
            score: score,
            total: questions.count,
            timeTaken: timeTaken,
            wrongTopics: wrongTopics,
            mode: "solo"
        )
    }
}
