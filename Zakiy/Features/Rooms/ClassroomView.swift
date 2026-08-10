import SwiftUI

/// Live-lesson room UI: shared whiteboard (with granted-permission drawing), voice chat, raised
/// hands, and an optional embedded quiz — the host can start one from any book at any point.
struct ClassroomView: View {
    @Bindable var socket: RoomSocketManager

    @State private var showManagement = false
    @State private var showInvite = false
    @State private var showChat = false
    @State private var showParticipants = false
    @State private var showQuizSetup = false
    /// A local flag, not a computed check of `quiz != nil && quizStartedAt != nil` — the server
    /// state stays "quiz active" forever once a quiz starts, so a computed check would make
    /// "return to room" impossible (it'd just swap right back to the quiz).
    @State private var isViewingQuizPlay = false

    var body: some View {
        Group {
            if isViewingQuizPlay {
                RoomQuizPlayView(socket: socket) { isViewingQuizPlay = false }
            } else if !socket.roomState.classStarted && !socket.roomState.isHost {
                waitingForHost
            } else {
                classroomContent
            }
        }
        .background(Color.appBackground)
        .toolbar {
            // A single native Menu instead of several individual ToolbarItems: with a leading
            // "ابدأ اختبار" button also competing for space, too many separate toolbar items can
            // still get silently collapsed by iOS into a dead-looking overflow glyph. A Menu is
            // one guaranteed-interactive item regardless of how much room is left.
            if !isViewingQuizPlay {
                if socket.roomState.canManageContent {
                    // .topBarTrailing, not .topBarLeading — "leading" resolves to the physical
                    // right edge in our RTL app; .trailing puts it on the actual physical left.
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(Loc.t("start_quiz")) { showQuizSetup = true }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showChat = true } label: { Label(Loc.t("chat"), systemImage: "bubble.left.and.bubble.right") }
                        Button { showParticipants = true } label: { Label(Loc.t("participants"), systemImage: "person.3") }
                        if socket.roomState.isHost {
                            Button { showInvite = true } label: { Label(Loc.t("invite_friends"), systemImage: "person.badge.plus") }
                            Button { showManagement = true } label: { Label(Loc.t("room_management"), systemImage: "gearshape") }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showManagement) {
            RoomManagementPanel(socket: socket)
        }
        .sheet(isPresented: $showInvite) {
            RoomInviteView(roomCode: socket.roomState.roomCode, roomType: socket.roomState.roomType)
        }
        .sheet(isPresented: $showChat) {
            ClassroomChatSheet(socket: socket)
        }
        .sheet(isPresented: $showParticipants) {
            ClassroomParticipantsSheet(socket: socket)
        }
        .sheet(isPresented: $showQuizSetup) {
            RoomStudySetupSheet(socket: socket) { questions, duration in
                socket.startQuiz(questions, durationMinutes: duration)
            }
        }
        .onChange(of: socket.roomState.quizStartedAt) { oldValue, newValue in
            if oldValue == nil, newValue != nil { isViewingQuizPlay = true }
        }
        .onChange(of: socket.roomState.roomCode) { _, newCode in
            // Covers reconnecting mid-quiz: quizStartedAt is already set in the very first
            // room_state snapshot (arrives asynchronously), so the onChange above alone misses it.
            guard !newCode.isEmpty else { return }
            if socket.roomState.quiz != nil, socket.roomState.quizStartedAt != nil {
                isViewingQuizPlay = true
            }
        }
    }

    private var classroomContent: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 0) {
                WhiteboardCanvasView(socket: socket)
                    .frame(maxHeight: .infinity)
                VoiceBarView(socket: socket)
            }

            if !socket.roomState.classStarted && socket.roomState.isHost {
                Button {
                    socket.startClass()
                } label: {
                    Text(Loc.t("start_class")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.appPrimary)
                .padding()
            }

            if !socket.roomState.raisedHands.isEmpty {
                raisedHandsBar
            }

            bottomBar
        }
    }

    private var header: some View {
        HStack {
            Text(String(format: Loc.t("room_code_label"), socket.roomState.roomCode))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            if socket.roomState.isHost {
                Text(Loc.t("host_badge"))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2), in: Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var waitingForHost: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(Loc.t("waiting_for_host")).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var raisedHandsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(socket.roomState.raisedHands) { hand in
                    Label(hand.name, systemImage: "hand.raised.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 6)
    }

    private var bottomBar: some View {
        HStack {
            Button {
                socket.raiseHand()
            } label: {
                Label(Loc.t("raise_hand"), systemImage: "hand.raised.fill")
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }
}

private struct ClassroomChatSheet: View {
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

private struct ClassroomParticipantsSheet: View {
    @Bindable var socket: RoomSocketManager
    @Environment(\.dismiss) private var dismiss

    // Once anyone has quiz results, show the list ranked with medals for the top 3 instead of
    // the plain roster — this is how everyone in a classroom (not just whoever is still on the
    // quiz results screen) gets to see how the embedded quiz turned out.
    private var hasAnyFinishedResults: Bool { socket.leaderboard.contains { $0.finished } }
    private var orderedParticipants: [RoomParticipant] {
        hasAnyFinishedResults ? socket.leaderboard.sorted { $0.score > $1.score } : socket.leaderboard
    }

    var body: some View {
        NavigationStack {
            List(Array(orderedParticipants.enumerated()), id: \.element.id) { index, participant in
                HStack {
                    if hasAnyFinishedResults {
                        Text(medal(for: index)).font(.subheadline).frame(width: 24)
                    } else {
                        Image(systemName: participant.inVoice ? "mic.fill" : "person.fill")
                            .foregroundStyle(.secondary)
                    }
                    Text(participant.name)
                    if participant.isCoHost {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(Color.accentColor)
                    }
                    Spacer()
                    if hasAnyFinishedResults {
                        if participant.finished {
                            Text("\(participant.score)/\(participant.total)").foregroundStyle(.secondary)
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
            }
            .navigationTitle(String(format: Loc.t("participants_count"), socket.leaderboard.count))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Loc.t("close")) { dismiss() }
                }
            }
        }
    }

    private func medal(for rank: Int) -> String {
        switch rank {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "\(rank + 1)."
        }
    }
}
