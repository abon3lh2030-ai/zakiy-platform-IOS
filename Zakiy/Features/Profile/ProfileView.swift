import SwiftUI

struct ProfileView: View {
    /// nil means "my own profile"
    let userId: String?

    @Environment(SupabaseAuthManager.self) private var auth
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var isOwnProfile: Bool {
        userId == nil || userId == auth.userId
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(Loc.t("loading")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile {
                ScrollView {
                    VStack(spacing: 20) {
                        header(profile)

                        if let summary = profile.summary {
                            statsGrid(summary)
                        }

                        if profile.showArchive != false {
                            NavigationLink {
                                ArchiveListView()
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
                                ProfileSettingsView()
                            } label: {
                                Text(Loc.t("privacy_settings"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
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
                .foregroundStyle(.accentColor)
            Text(profile.username).font(.title2.bold())
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    private func statsGrid(_ summary: ProfileSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: Loc.t("total_sessions"), value: "\(summary.totalSessions)")
            statCard(title: Loc.t("average_score"), value: String(format: "%.0f%%", summary.averageScore))
            statCard(title: Loc.t("sessions_hosted"), value: "\(summary.sessionsHosted)")
            statCard(title: Loc.t("friends_count"), value: "\(summary.friendsCount)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.title2.bold()).foregroundStyle(.accentColor)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        isLoading = true
        do {
            if let userId, userId != auth.userId {
                profile = try await APIClient.shared.userProfile(userId: userId)
            } else {
                profile = try await APIClient.shared.myProfile()
            }
        } catch {
            errorMessage = Loc.t("error_generic")
        }
        isLoading = false
    }
}
