import SwiftUI

/// Compact voice-chat control bar: join/leave the mesh, mute toggle, and a strip of the
/// participants currently in voice.
struct VoiceBarView: View {
    @Bindable var socket: RoomSocketManager
    @State private var voice = WebRTCVoiceManager()

    private var inVoiceParticipants: [RoomParticipant] {
        socket.leaderboard.filter(\.inVoice)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if voice.isInVoice {
                    voice.leaveVoice()
                } else {
                    voice.joinVoice()
                }
            } label: {
                Label(voice.isInVoice ? Loc.t("leave_voice") : Loc.t("join_voice"), systemImage: voice.isInVoice ? "phone.down.fill" : "mic.fill")
            }
            .buttonStyle(.bordered)
            .tint(voice.isInVoice ? .red : .accentColor)
            .controlSize(.small)

            if voice.isInVoice {
                Button {
                    voice.toggleMute()
                } label: {
                    Image(systemName: voice.isMuted ? "mic.slash.fill" : "mic.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !inVoiceParticipants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(inVoiceParticipants) { participant in
                            VStack(spacing: 2) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                Text(participant.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.appCard)
        .onAppear { voice.attach(socket: socket) }
        .onDisappear { if voice.isInVoice { voice.leaveVoice() } }
        .onChange(of: socket.forceMutedSignal) { _, _ in
            if voice.isInVoice { voice.applyForceMute() }
        }
    }
}
