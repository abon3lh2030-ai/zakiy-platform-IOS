import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SupabaseAuthManager.self) private var auth

    @State private var showLogin = false
    @State private var showSignUp = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                if auth.isAuthenticated {
                    LabeledContent(Loc.t("username"), value: auth.username)
                    if let email = auth.email { LabeledContent(Loc.t("email"), value: email) }
                    NavigationLink { ProfileView(userId: nil) } label: {
                        SettingsRow(icon: "person.text.rectangle.fill", tint: .purple, title: Loc.t("my_profile"), subtitle: Loc.t("my_profile_subtitle"))
                    }
                    NavigationLink { EditProfileView() } label: {
                        SettingsRow(icon: "person.crop.circle.fill", tint: .indigo, title: Loc.t("edit_profile"), subtitle: Loc.t("edit_profile_subtitle"))
                    }
                } else {
                    Text(settings.isGuest ? Loc.t("guest_mode_label") : Loc.t("not_logged_in_label"))
                        .foregroundStyle(.secondary)

                    Button { showLogin = true } label: {
                        Text(Loc.t("login")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.appPrimary)

                    Button { showSignUp = true } label: {
                        Text(Loc.t("signup")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section {
                NavigationLink { SubscriptionView() } label: {
                    SettingsRow(icon: "crown.fill", tint: .orange, title: Loc.t("subscription"), subtitle: Loc.t("subscription_subtitle"))
                }
                NavigationLink { FriendsListView() } label: {
                    SettingsRow(icon: "person.2.fill", tint: .blue, title: Loc.t("friends"), subtitle: Loc.t("friends_subtitle"))
                }
                NavigationLink { ArchiveListView() } label: {
                    SettingsRow(icon: "archivebox.fill", tint: .gray, title: Loc.t("archive"), subtitle: Loc.t("archive_subtitle"))
                }
            }

            Section(Loc.t("language")) {
                Picker(Loc.t("language"), selection: $settings.languageCode) {
                    Text("العربية").tag("ar")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
            }

            Section(Loc.t("appearance")) {
                Picker(Loc.t("appearance"), selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(Loc.t(mode.labelKey)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if auth.isAuthenticated {
                Section {
                    Button(role: .destructive) {
                        Task { try? await auth.signOut() }
                    } label: {
                        Text(Loc.t("logout")).frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(Loc.t("settings"))
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(isPresented: $showSignUp) { SignUpView() }
    }
}

private struct SettingsRow: View {
    let icon: String
    var tint: Color = .accentColor
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
