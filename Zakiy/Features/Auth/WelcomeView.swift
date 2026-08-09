import SwiftUI

struct WelcomeView: View {
    @Environment(AppSettings.self) private var settings
    @State private var showLogin = false
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180)
                VStack(spacing: 8) {
                    Text(Loc.t("welcome_title"))
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(Loc.t("welcome_subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        showSignUp = true
                    } label: {
                        Text(Loc.t("signup")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.appPrimary)
                    .controlSize(.large)

                    Button {
                        showLogin = true
                    } label: {
                        Text(Loc.t("login")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(Loc.t("continue_guest")) {
                        withAnimation { settings.isGuest = true }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
            .sheet(isPresented: $showLogin) { LoginView() }
            .sheet(isPresented: $showSignUp) { SignUpView() }
        }
    }
}
