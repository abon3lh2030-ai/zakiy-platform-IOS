import SwiftUI

struct ProfileView: View {
    /// nil means "my own profile"
    let userId: String?

    @Environment(SupabaseAuthManager.self) private var auth
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var isOwnProfile: Bool {
        (userId == nil) || (userId == auth.userId)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile {
                ScrollView {
                    VStack(spacing: 20) {
                        header(profile)

                        if let performance = profile.performance {
                            statsGrid(performance, friendsCount: profile.friends?.count)
                        }

                        if let archive = profile.archive, !archive.isEmpty {
                            NavigationLink {
                                if isOwnProfile {
                                    ArchiveListView()
                                } else {
                                    ProfileArchiveListView(items: archive)
                                }
                            } label: {
                                HStack {
                                    Label(Loc.t("archive"), systemImage: "archivebox.fill")
                                    Spacer()
                                    Image(systemName: "chevron.forward")
                                }
                                .padding()
                                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.appAccentText)
                        }

                        if isOwnProfile {
                            NavigationLink {
                                ProfileSettingsView(profile: profile)
                            } label: {
                                Text(Loc.t("privacy_settings"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        } else if profile.friendStatus == "none" {
                            Button {
                                Task { await sendFriendRequest() }
                            } label: {
                                Text(Loc.t("add_friend")).frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.appPrimary)
                        } else if profile.friendStatus == "pending_sent" {
                            Text(Loc.t("friend_request_sent")).foregroundStyle(.secondary)
                        } else if profile.friendStatus == "pending_received" {
                            Text(Loc.t("incoming_request_notice")).foregroundStyle(.secondary)
                        } else if profile.friendStatus == "friends" {
                            Label(Loc.t("friends"), systemImage: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(Loc.t("profile"), systemImage: "person.crop.circle.badge.exclamationmark", description: Text(errorMessage ?? Loc.t("error_generic")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(isOwnProfile ? Loc.t("my_profile") : Loc.t("profile"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func header(_ profile: UserProfile) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .foregroundStyle(Color.accentColor)
            Text(profile.username).font(.title2.bold())
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    private func statsGrid(_ performance: ProfilePerformanceSummary, friendsCount: Int?) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: Loc.t("total_attempts"), value: "\(performance.attemptsCount)")
            statCard(title: Loc.t("average_score"), value: "\(performance.avgScore)%")
            statCard(title: Loc.t("current_streak"), value: "\(performance.currentStreak)")
            if let friendsCount {
                statCard(title: Loc.t("friends_count"), value: "\(friendsCount)")
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.title2.bold()).foregroundStyle(Color.accentColor)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        isLoading = true
        let targetId = userId ?? auth.userId ?? ""
        do {
            profile = try await APIClient.shared.fullProfile(userId: targetId)
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isLoading = false
    }

    private func sendFriendRequest() async {
        guard let userId else { return }
        try? await APIClient.shared.sendFriendRequest(toUserId: userId)
        await load()
    }
}

/// Read-only archive list for viewing another user's shared sessions (their own APIClient.sessionsArchive()
/// call would return *my* sessions, not theirs — so we just render the items already embedded in their profile).
private struct ProfileArchiveListView: View {
    let items: [SessionArchiveItem]
    @State private var selected: SessionArchiveItem?

    var body: some View {
        List(items) { item in
            Button { selected = item } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.hostName.map { String(format: Loc.t("session_hosted_by"), $0) } ?? item.roomCode ?? Loc.t("archive"))
                        .font(.headline)
                    if let createdAt = item.createdAt {
                        Text(createdAt).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(Loc.t("archive"))
        .navigationDestination(item: $selected) { item in
            ArchiveDetailView(item: item)
        }
    }
}
