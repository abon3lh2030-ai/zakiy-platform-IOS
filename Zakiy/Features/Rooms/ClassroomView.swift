import SwiftUI

/// Live-lesson room UI: shared whiteboard, voice chat, raised hands, and text chat side panel.
struct ClassroomView: View {
    @Bindable var socket: RoomSocketManager

    @State private var showManagement = false
    @State private var showInvite = false
    @State private var showChat = false
    @State private var showParticipants = false

    var body: some View {
        VStack(spacing: 0) {
            if !socket.roomState.classStarted && !socket.roomState.isHost {
                waitingForHost
            } else {
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
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 14) {
                    Button { showChat = true } label: { Image(systemName: "bubble.left.and.bubble.right") }
                    Button { showParticipants = true } label: { Image(systemName: "person.3") }
                    if socket.roomState.isHost {
                        Button { showInvite = true } label: { Image(systemName: "person.badge.plus") }
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
    @State private var input = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(socket.chatMessages) { message in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(message.name).font(.caption.bold()).foregroundStyle(Color.accentColor)
                                    Text(message.message).font(.subheadline)
                                }
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: socket.chatMessages.count) {
                        if let last = socket.chatMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                Divider()
                HStack {
                    TextField(Loc.t("type_a_message"), text: $input)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let text = input.trimmingCharacters(in: .whitespaces)
                        guard !text.isEmpty else { return }
                        socket.sendChatMessage(text)
                        input = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
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
