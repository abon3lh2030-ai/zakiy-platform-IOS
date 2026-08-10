import SwiftUI

struct RoomQuizPlayView: View {
    @Bindable var socket: RoomSocketManager
    /// Pops back to the room's normal view (participants/whiteboard) — a plain system back
    /// button won't do this reliably since the room's "quiz active" state is server-driven and
    /// would just push the quiz screen right back onto the stack.
    let onReturnToRoom: () -> Void

    @State private var currentIndex = 0
    @State private var selectedOption: Int?
    @State private var score = 0
    @State private var wrongTopics: [String] = []
    @State private var hasFinished = false
    @State private var startedAt = Date()

    private var questions: [QuizQuestion] { socket.roomState.quiz ?? [] }

    var body: some View {
        Group {
            if questions.isEmpty {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hasFinished {
                waitingView
            } else {
                questionView
            }
        }
        .background(Color.appBackground)
        .navigationTitle(Loc.t("generate_quiz"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { startedAt = Date() }
    }

    private var questionView: some View {
        let question = questions[currentIndex]
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(format: Loc.t("question_number"), currentIndex + 1, questions.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(question.question).font(.title3.bold())

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

    private var waitingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.accentColor)
                Text(String(format: Loc.t("your_score_format"), score, questions.count))
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 10) {
                    Text(Loc.t("leaderboard")).font(.headline)
                    ForEach(Array(sortedLeaderboard.enumerated()), id: \.offset) { index, participant in
                        HStack {
                            Text(medal(for: index))
                                .font(.subheadline)
                                .frame(width: 24)
                            Text(participant.name)
                            Spacer()
                            if participant.finished {
                                Text("\(participant.score)/\(participant.total)")
                            } else {
                                ProgressView().controlSize(.small)
                            }
                        }
                        .font(.subheadline)
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))

                // Everyone finishes at their own pace, so this button doesn't wait for the rest
                // of the room — it just takes you back to the shared room view where the live
                // leaderboard above keeps updating for everyone as others finish too.
                Button {
                    onReturnToRoom()
                } label: {
                    Text(Loc.t("return_to_room")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.appPrimary)
            }
            .padding()
        }
    }

    private var sortedLeaderboard: [RoomParticipant] {
        socket.leaderboard.sorted { $0.score > $1.score }
    }

    private func medal(for rank: Int) -> String {
        switch rank {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "\(rank + 1)."
        }
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
            finish()
        } else {
            currentIndex += 1
        }
    }

    private func finish() {
        hasFinished = true
        let timeTaken = Int(Date().timeIntervalSince(startedAt))
        socket.submitScore(score: score, total: questions.count, timeTaken: timeTaken, wrongTopics: wrongTopics)
    }
}
