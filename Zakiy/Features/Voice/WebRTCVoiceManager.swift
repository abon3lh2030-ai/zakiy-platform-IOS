@preconcurrency import WebRTC
import Observation
import Foundation

/// `RTCPeerConnection.delegate` is `weak`, so each peer needs a strongly-referenced delegate box
/// kept alive for as long as the connection exists.
private final class PeerConnectionDelegateBox: NSObject, RTCPeerConnectionDelegate {
    let sid: String
    weak var manager: WebRTCVoiceManager?

    init(sid: String, manager: WebRTCVoiceManager) {
        self.sid = sid
        self.manager = manager
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Task { @MainActor [weak self] in
            self?.manager?.handleIceConnectionChange(sid: self?.sid ?? "", state: newState)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let sid = self.sid
        Task { @MainActor [weak self] in
            self?.manager?.sendLocalCandidate(candidate, to: sid)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

@MainActor
@Observable
final class WebRTCVoiceManager {
    var isInVoice = false
    var isMuted = false
    nonisolated(unsafe) var speakingSids: Set<String> = []

    private var factory: RTCPeerConnectionFactory?
    private var peerConnections: [String: RTCPeerConnection] = [:]
    private var delegateBoxes: [String: PeerConnectionDelegateBox] = [:]
    private var localAudioTrack: RTCAudioTrack?
    private weak var socket: RoomSocketManager?

    private static let iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]

    func attach(socket: RoomSocketManager) {
        self.socket = socket

        // Real backend protocol (socket.io handlers in app.py): the newly-joining peer receives
        // the existing roster and initiates an offer to each; peers already in voice just wait
        // for that offer to arrive rather than also initiating one themselves (avoids glare).
        socket.onVoiceEvent("voice_existing_peers") { [weak self] data in
            guard let peers = data["peers"] as? [[String: Any]] else { return }
            let sids = peers.compactMap { $0["sid"] as? String }
            Task { @MainActor in self?.connectToExistingPeers(sids) }
        }
        socket.onVoiceEvent("voice_peer_left") { [weak self] data in
            guard let sid = data["sid"] as? String else { return }
            Task { @MainActor in self?.removePeer(sid) }
        }
        socket.onVoiceEvent("voice_offer") { [weak self] data in
            guard let fromSid = data["from_sid"] as? String,
                  let offer = data["offer"] as? [String: Any],
                  let sdp = offer["sdp"] as? String else { return }
            Task { @MainActor in self?.handleOffer(from: fromSid, sdp: sdp) }
        }
        socket.onVoiceEvent("voice_answer") { [weak self] data in
            guard let fromSid = data["from_sid"] as? String,
                  let answer = data["answer"] as? [String: Any],
                  let sdp = answer["sdp"] as? String else { return }
            Task { @MainActor in self?.handleAnswer(from: fromSid, sdp: sdp) }
        }
        socket.onVoiceEvent("voice_ice_candidate") { [weak self] data in
            guard let fromSid = data["from_sid"] as? String,
                  let candidateDict = data["candidate"] as? [String: Any],
                  let candidateString = candidateDict["candidate"] as? String,
                  let sdpMid = candidateDict["sdpMid"] as? String,
                  let sdpMLineIndex = candidateDict["sdpMLineIndex"] as? Int else { return }
            Task { @MainActor in self?.handleRemoteCandidate(from: fromSid, candidateString: candidateString, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex) }
        }
    }

    func joinVoice() {
        guard !isInVoice else { return }
        configureAudioSession()
        setupFactoryIfNeeded()
        isInVoice = true
        socket?.emitVoiceJoin()
    }

    func leaveVoice() {
        guard isInVoice else { return }
        isInVoice = false
        socket?.emitVoiceLeave()
        for sid in Array(peerConnections.keys) { removePeer(sid) }
        localAudioTrack = nil
    }

    func toggleMute() {
        isMuted.toggle()
        localAudioTrack?.isEnabled = !isMuted
    }

    /// Called when the host force-mutes us server-side — enforce it locally too (the host
    /// can't reach into our audio track directly, only notify us via the `force_muted` event).
    func applyForceMute() {
        isMuted = true
        localAudioTrack?.isEnabled = false
    }

    private func setupFactoryIfNeeded() {
        guard factory == nil else { return }
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let newFactory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
        factory = newFactory

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = newFactory.audioSource(with: constraints)
        localAudioTrack = newFactory.audioTrack(with: audioSource, trackId: "zakiy-audio-\(RoomSocketManager.persistentClientId)")
    }

    private func configureAudioSession() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            // Non-fatal: voice will simply not have optimal routing.
        }
        session.unlockForConfiguration()
    }

    private func connectToExistingPeers(_ sids: [String]) {
        for sid in sids {
            createPeerConnection(for: sid, isOfferer: true)
        }
    }

    private func createPeerConnection(for sid: String, isOfferer: Bool) {
        guard peerConnections[sid] == nil, let factory else { return }

        let config = RTCConfiguration()
        config.iceServers = Self.iceServers
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

        let delegateBox = PeerConnectionDelegateBox(sid: sid, manager: self)
        guard let connection = factory.peerConnection(with: config, constraints: constraints, delegate: delegateBox) else { return }

        if let localAudioTrack {
            connection.add(localAudioTrack, streamIds: ["zakiy-stream"])
        }

        peerConnections[sid] = connection
        delegateBoxes[sid] = delegateBox

        if isOfferer {
            let offerConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            connection.offer(for: offerConstraints) { [weak self] sdp, _ in
                guard let sdp else { return }
                connection.setLocalDescription(sdp) { _ in }
                Task { @MainActor in
                    self?.socket?.emitVoiceOffer(to: sid, sdp: sdp.sdp)
                }
            }
        }
    }

    private func handleOffer(from sid: String, sdp sdpString: String) {
        createPeerConnection(for: sid, isOfferer: false)
        guard let connection = peerConnections[sid] else { return }
        let remoteSdp = RTCSessionDescription(type: .offer, sdp: sdpString)
        connection.setRemoteDescription(remoteSdp) { [weak self] _ in
            let answerConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            connection.answer(for: answerConstraints) { sdp, _ in
                guard let sdp else { return }
                connection.setLocalDescription(sdp) { _ in }
                Task { @MainActor in
                    self?.socket?.emitVoiceAnswer(to: sid, sdp: sdp.sdp)
                }
            }
        }
    }

    private func handleAnswer(from sid: String, sdp sdpString: String) {
        guard let connection = peerConnections[sid] else { return }
        let remoteSdp = RTCSessionDescription(type: .answer, sdp: sdpString)
        connection.setRemoteDescription(remoteSdp) { _ in }
    }

    private func handleRemoteCandidate(from sid: String, candidateString: String, sdpMid: String, sdpMLineIndex: Int) {
        guard let connection = peerConnections[sid] else { return }
        let candidate = RTCIceCandidate(sdp: candidateString, sdpMLineIndex: Int32(sdpMLineIndex), sdpMid: sdpMid)
        connection.add(candidate) { _ in }
    }

    fileprivate func sendLocalCandidate(_ candidate: RTCIceCandidate, to sid: String) {
        socket?.emitVoiceIceCandidate(
            to: sid,
            candidate: candidate.sdp,
            sdpMid: candidate.sdpMid ?? "",
            sdpMLineIndex: Int(candidate.sdpMLineIndex)
        )
    }

    fileprivate func handleIceConnectionChange(sid: String, state: RTCIceConnectionState) {
        if state == .failed || state == .closed {
            removePeer(sid)
        }
    }

    private func removePeer(_ sid: String) {
        peerConnections[sid]?.close()
        peerConnections[sid] = nil
        delegateBoxes[sid] = nil
        speakingSids.remove(sid)
    }
}
