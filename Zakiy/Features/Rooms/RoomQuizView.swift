import SwiftUI

/// The pre-quiz / lobby screen for a "quiz" type room: participant list, host controls, chat.
/// Once the host starts the quiz, it hands off to `RoomQuizPlayView`.
struct RoomQuizView: View {
    @Bindable var socket: RoomSocketManager

    @State private var showSetup = false
    @State private var showManagement = false
    @State private var showInvite = false
    @State private var showChat = false

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
            // Separate ToolbarItems, not several Buttons grouped in one HStack under a single
            // item — grouping breaks iOS's overflow handling and can produce a dead "..." button.
            ToolbarItem(placement: .primaryAction) {
                Button { showChat = true } label: { Image(systemName: "bubble.left.and.bubble.right") }
            }
            if socket.roomState.isHost {
                ToolbarItem(placement: .primaryAction) {
                    Button { showInvite = true } label: { Image(systemName: "person.badge.plus") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showManagement = true } label: { Image(systemName: "gearshape") }
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
        .navigationDestination(isPresented: Binding(
            get: { socket.roomState.quiz != nil && socket.roomState.quizStartedAt != nil },
            set: { _ in }
        )) {
            RoomQuizPlayView(socket: socket)
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
