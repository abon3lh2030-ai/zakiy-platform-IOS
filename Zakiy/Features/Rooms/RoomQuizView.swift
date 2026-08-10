import SwiftUI

/// The pre-quiz / lobby screen for a "quiz" type room: participant list, host controls, chat.
/// Once the host starts the quiz, it hands off to `RoomQuizPlayView`.
struct RoomQuizView: View {
    @Bindable var socket: RoomSocketManager

    @State private var showSetup = false
    @State private var showManagement = false
    @State private var showInvite = false
    @State private var showChat = false
    @State private var isViewingQuizPlay = false

    private var hasAnyFinishedResults: Bool {
        socket.leaderboard.contains { $0.finished }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    codeCard

                    if let summary = socket.roomState.sharedSummary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Loc.t("shared_summary")).font(.headline)
                            Text(summary).font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Visible to everyone in the room, not just inside the quiz-play screen —
                    // updates live as each participant finishes, so results aren't only shown to
                    // whoever happens to still be on the results screen.
                    if hasAnyFinishedResults {
                        leaderboardSection
                    }

                    participantsSection
                }
                .padding()
            }

            if socket.roomState.isHost || socket.roomState.canManageContent {
                hostControls
            }
        }
        .background(Color.appBackground)
        .toolbar {
            // A single native Menu, not several individual ToolbarItems — with limited nav bar
            // width, iOS can still silently collapse multiple items into a dead-looking overflow
            // glyph. A Menu is one guaranteed-interactive item no matter how much room is left.
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showChat = true } label: { Label(Loc.t("chat"), systemImage: "bubble.left.and.bubble.right") }
                    if socket.roomState.isHost {
                        Button { showInvite = true } label: { Label(Loc.t("invite_friends"), systemImage: "person.badge.plus") }
                        Button { showManagement = true } label: { Label(Loc.t("room_management"), systemImage: "gearshape") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showSetup) {
            RoomStudySetupSheet(socket: socket) { questions, duration in
                socket.startQuiz(questions, durationMinutes: duration)
            }
        }
        .sheet(isPresented: $showManagement) {
            RoomManagementPanel(socket: socket)
        }
        .sheet(isPresented: $showInvite) {
            RoomInviteView(roomCode: socket.roomState.roomCode, roomType: socket.roomState.roomType)
        }
        .sheet(isPresented: $showChat) {
            RoomChatSheet(socket: socket)
        }
        // A real @State-backed binding (not a computed get with a discarded set) so both the
        // system back button and our own "return to room" button actually pop this off the
        // stack — the room's "quiz active" flag is server-driven and would otherwise just push
        // the quiz screen right back on.
        .onChange(of: socket.roomState.quizStartedAt) { oldValue, newValue in
            if oldValue == nil, newValue != nil { isViewingQuizPlay = true }
        }
        .onChange(of: socket.roomState.roomCode) { _, newCode in
            // Covers reconnecting mid-quiz (e.g. app relaunch): quizStartedAt is already set in
            // the very first room_state snapshot (which arrives asynchronously after this view
            // appears), so onChange(of: quizStartedAt) never sees a nil→non-nil transition for it.
            guard !newCode.isEmpty else { return }
            if socket.roomState.quiz != nil, socket.roomState.quizStartedAt != nil {
                isViewingQuizPlay = true
            }
        }
        .navigationDestination(isPresented: $isViewingQuizPlay) {
            RoomQuizPlayView(socket: socket) { isViewingQuizPlay = false }
        }
    }

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Loc.t("leaderboard")).font(.headline)
            ForEach(Array(sortedLeaderboard.enumerated()), id: \.offset) { index, participant in
                HStack {
                    Text(medal(for: index)).font(.subheadline).frame(width: 24)
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

    private var codeCard: some View {
        VStack(spacing: 6) {
            Text(Loc.t("room_code")).font(.caption).foregroundStyle(.secondary)
            Text(socket.roomState.roomCode)
                .font(.system(.title, design: .rounded).bold())
                .kerning(4)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
    }

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: Loc.t("participants_count"), socket.leaderboard.count)).font(.headline)
            ForEach(socket.leaderboard) { participant in
                HStack {
                    Image(systemName: participant.inVoice ? "mic.fill" : "person.fill")
                        .foregroundStyle(.secondary)
                    Text(participant.name)
                    if participant.isCoHost {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(Color.accentColor)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private var hostControls: some View {
        VStack(spacing: 10) {
            Divider()
            Button {
                showSetup = true
            } label: {
                Text(Loc.t("start_study_button")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.appPrimary)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color.appBackground)
    }
}

private struct RoomChatSheet: View {
    @Bindable var socket: RoomSocketManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RoomChatBody(socket: socket)
                .navigationTitle(Loc.t("chat"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Loc.t("close")) { dismiss() }
                    }
                }
        }
    }
}
