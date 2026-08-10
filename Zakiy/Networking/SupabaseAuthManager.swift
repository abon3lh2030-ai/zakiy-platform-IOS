import Foundation
import Supabase
import Observation

@MainActor
@Observable
final class SupabaseAuthManager {
    static let shared = SupabaseAuthManager()

    let client: SupabaseClient
    var session: Session?
    var isBootstrapping = true

    private init() {
        client = SupabaseClient(supabaseURL: APIConfig.supabaseURL, supabaseKey: APIConfig.supabaseAnonKey)
        Task { await observeAuthState() }
    }

    var isAuthenticated: Bool { session != nil }
    var accessToken: String? { session?.accessToken }
    var userId: String? { session?.user.id.uuidString.lowercased() }
    var email: String? { session?.user.email }

    var username: String {
        if case let .string(name)? = session?.user.userMetadata["username"] {
            return name
        }
        return email ?? Loc.t("default_student_name")
    }

    var phone: String {
        if case let .string(phone)? = session?.user.userMetadata["phone"] {
            return phone
        }
        return ""
    }

    private func observeAuthState() async {
        for await state in client.auth.authStateChanges {
            session = state.session
            isBootstrapping = false
        }
    }

    func signIn(email: String, password: String) async throws {
        session = try await client.auth.signIn(email: email, password: password)
        AppSettings.shared.isGuest = false
    }

    func signUp(email: String, password: String, username: String, educationLevel: String, proficiencyLevel: String) async throws -> Bool {
        let metadata: [String: AnyJSON] = [
            "username": .string(username),
            "education_level": .string(educationLevel),
            "proficiency_level": .string(proficiencyLevel),
        ]
        let response = try await client.auth.signUp(email: email, password: password, data: metadata)
        session = response.session
        if response.session != nil {
            AppSettings.shared.isGuest = false
            // Creates the searchable `profiles` row up front — without this, a brand-new user
            // can't be found by friend search until they happen to open their own profile page
            // (which lazily creates it server-side) or edit it manually.
            try? await APIClient.shared.syncProfile(username: username)
        }
        return response.session != nil
    }

    func signOut() async throws {
        defer { session = nil }
        try await client.auth.signOut()
    }

    func updateProfile(username: String? = nil, phone: String? = nil) async throws {
        var metadata: [String: AnyJSON] = [:]
        if let username { metadata["username"] = .string(username) }
        if let phone { metadata["phone"] = .string(phone) }
        guard !metadata.isEmpty else { return }
        let attrs = UserAttributes(data: metadata)
        _ = try await client.auth.update(user: attrs)
        try? await APIClient.shared.syncProfile(username: username ?? self.username)
    }

    func updatePassword(_ newPassword: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }
}
