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

    private var isQuizActive: Bool {
        socket.roomState.quiz != nil && socket.roomState.quizStartedAt != nil
    }

    var body: some View {
        Group {
            if isQuizActive {
                RoomQuizPlayView(socket: socket)
            } else if !socket.roomState.classStarted && !socket.roomState.isHost {
                waitingForHost
            } else {
                classroomContent
            }
        }
        .background(Color.appBackground)
        .toolbar {
            // Each button is its own ToolbarItem (never several Buttons grouped inside one
            // HStack under a single ToolbarItem) — grouping them breaks iOS's own overflow
            // handling and can leave a dead "..." button that does nothing when tapped.
            if !isQuizActive {
                if socket.roomState.canManageContent {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(Loc.t("start_quiz")) { showQuizSetup = true }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showChat = true } label: { Image(systemName: "bubble.left.and.bubble.right") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showParticipants = true } label: { Image(systemName: "person.3") }
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

    var body: some View {
        NavigationStack {
            List(socket.leaderboard) { participant in
                HStack {
                    Image(systemName: participant.inVoice ? "mic.fill" : "person.fill")
                        .foregroundStyle(.secondary)
                    Text(participant.name)
                    if participant.isCoHost {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(Color.accentColor)
                    }
                    Spacer()
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
}
