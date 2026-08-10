import Foundation
import SocketIO
import Observation

/// اتصال Socket.IO عام مستقل عن `RoomSocketManager` (اللي عمره مربوط بجلسة
/// غرفة دراسة وحدة وينقطع لما تطلع منها) - هذا يبقى شغال طول ما التطبيق فاتح
/// ومسجّل دخول، عشان يستلم تنبيهاته (رسالة/بث جماعي/تذكير حصة/بدء حصة) لحظيًا
/// بأي مكان بالتطبيق، مو بس وهو داخل غرفة. singleton بنفس نمط APIClient/AuthManager.
@MainActor
@Observable
final class NotificationSocketManager {
    static let shared = NotificationSocketManager()

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var isRegistered = false

    /// يتحدّث فورًا لحظة وصول تنبيه جديد (زيادة محلية)، وبرضو من `refreshUnreadCount()`
    /// اللي تجيب العدد الحقيقي من الباك إند (بعد فتح شاشة الرسائل مثلًا).
    var unreadCount = 0

    private init() {}

    func connectIfNeeded() {
        guard socket == nil else { return }
        let manager = SocketManager(socketURL: APIConfig.apiBase, config: [.log(false), .compress, .forceWebsockets(true)])
        self.manager = manager
        let socket = manager.defaultSocket
        self.socket = socket

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in self?.registerUser() }
        }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.isRegistered = false }
        }
        socket.on("new_notification") { [weak self] _, _ in
            Task { @MainActor in self?.unreadCount += 1 }
        }

        socket.connect()
    }

    /// يُنادى بعد كل دخول ناجح (التوكن صار متاح لأول مرة) - لو السوكيت أصلًا
    /// متصل من قبل (كضيف)، حدث connect ما يعيد الإطلاق لمجرد صار عندنا توكن،
    /// فلازم نسجّل الهوية صراحة هنا كمان.
    func registerUser() {
        guard let token = SupabaseAuthManager.shared.accessToken else { return }
        socket?.emit("register_user", ["token": token])
        isRegistered = true
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
        isRegistered = false
        unreadCount = 0
    }

    func refreshUnreadCount() async {
        guard let data = try? await APIClient.shared.notifications() else { return }
        unreadCount = data.unreadCount
    }
}
