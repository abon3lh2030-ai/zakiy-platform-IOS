import SwiftUI
import UniformTypeIdentifiers

@main
struct ZakiyApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(Theme.gold)
                .preferredColorScheme(app.appearance.colorScheme)
        }
    }
}

enum Theme {
    static let navy = Color(red: 27 / 255, green: 42 / 255, blue: 74 / 255)
    static let navyDark = Color(red: 20 / 255, green: 29 / 255, blue: 40 / 255)
    static let beige = Color(red: 250 / 255, green: 249 / 255, blue: 246 / 255)
    static let cardLight = Color.white
    static let cardDark = Color(red: 31 / 255, green: 43 / 255, blue: 57 / 255)
    static let gold = Color(red: 255 / 255, green: 201 / 255, blue: 60 / 255)
    static let teal = Color(red: 46 / 255, green: 139 / 255, blue: 119 / 255)
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? { self == .system ? nil : (self == .light ? .light : .dark) }
}

final class AppState: ObservableObject {
    @Published var isLoggedIn = false
    @Published var username = UserDefaults.standard.string(forKey: "zakiy.name") ?? "طالب"
    @Published var email = UserDefaults.standard.string(forKey: "zakiy.email") ?? ""
    @Published var appearance: Appearance = Appearance(rawValue: UserDefaults.standard.string(forKey: "zakiy.appearance") ?? "system") ?? .system {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "zakiy.appearance") }
    }

    func saveProfile(name: String, email: String) {
        username = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(username, forKey: "zakiy.name")
        UserDefaults.standard.set(self.email, forKey: "zakiy.email")
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @State private var showWelcome = false

    var body: some View {
        Group {
            if app.isLoggedIn || !showWelcome {
                MainTabView(showWelcome: $showWelcome)
            } else {
                WelcomeView(showWelcome: $showWelcome)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct MainTabView: View {
    @Binding var showWelcome: Bool

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("الرئيسية", systemImage: "house.fill") }
            NavigationStack { RoomsHubView() }
                .tabItem { Label("الغرف", systemImage: "person.3.fill") }
            NavigationStack { LibraryView() }
                .tabItem { Label("المكتبة", systemImage: "books.vertical.fill") }
            NavigationStack { PerformanceView() }
                .tabItem { Label("أدائي", systemImage: "chart.line.uptrend.xyaxis") }
            NavigationStack { SettingsView(showWelcome: $showWelcome) }
                .tabItem { Label("الإعدادات", systemImage: "gearshape.fill") }
        }
    }
}

struct WelcomeView: View {
    @Binding var showWelcome: Bool
    @EnvironmentObject private var app: AppState
    @State private var name = ""

    var body: some View {
        ZStack {
            Theme.beige.ignoresSafeArea()
            VStack(spacing: 28) {
                BrandMark(size: 132)
                VStack(spacing: 8) {
                    Text("أهلًا بك في ذكيّ").font(.largeTitle.bold()).foregroundStyle(Theme.navy)
                    Text("منصة مذاكرة جماعية بمساعدة الذكاء الاصطناعي")
                        .multilineTextAlignment(.center).foregroundStyle(Theme.navy.opacity(0.7))
                }
                TextField("اكتب اسمك", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 28)
                Button("ابدأ الآن") {
                    app.saveProfile(name: name.isEmpty ? "طالب" : name, email: "")
                    app.isLoggedIn = true
                    showWelcome = false
                }
                .buttonStyle(GoldButtonStyle())
                .padding(.horizontal, 28)
            }
        }
    }
}

struct BrandMark: View {
    var size: CGFloat = 42
    var body: some View {
        VStack(spacing: 7) {
            Text("ذكيّ")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(Theme.navy)
            Capsule().fill(Theme.gold).frame(width: size * 1.4, height: max(5, size * 0.08))
        }
        .accessibilityLabel("ذكيّ")
    }
}

struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .background(scheme == .dark ? Theme.cardDark : Theme.cardLight, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.navy.opacity(scheme == .dark ? 0.22 : 0.08), lineWidth: 1))
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.06), radius: 9, y: 4)
    }
}

struct ScreenBackground<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ZStack { (scheme == .dark ? Theme.navyDark : Theme.beige).ignoresSafeArea(); content }
    }
}

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var showImporter = false
    @State private var selectedFile = ""

    var body: some View {
        ScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { BrandMark(size: 34); Spacer() }
                    Text("أهلًا، \(app.username.isEmpty ? "طالب" : app.username)")
                        .font(.title.bold())
                    Text("وش تبغى تبدأ اليوم؟").foregroundStyle(.secondary)
                    ActionLink(icon: "doc.badge.plus", title: "ارفع ملف PDF", subtitle: selectedFile.isEmpty ? "لخص كتابك وابدأ مذاكرة فردية" : selectedFile, tint: Theme.gold) { showImporter = true }
                    NavigationLink { RoomLobbyView(type: .group) } label: {
                        RoomCard(icon: "person.3.fill", title: "غرفة جماعية", subtitle: "مذاكرة واختبار مع زملائك", tint: Theme.teal)
                    }.buttonStyle(.plain)
                    NavigationLink { RoomLobbyView(type: .lesson) } label: {
                        RoomCard(icon: "person.crop.rectangle.stack.fill", title: "درس مباشر", subtitle: "سبورة وصوت وطلاب", tint: Theme.gold)
                    }.buttonStyle(.plain)
                }
                .padding()
            }
        }
        .navigationTitle("الرئيسية")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result { selectedFile = url.lastPathComponent }
        }
    }
}

struct ActionLink: View {
    let icon: String; let title: String; let subtitle: String; let tint: Color; let action: () -> Void
    var body: some View {
        Button(action: action) { RoomCard(icon: icon, title: title, subtitle: subtitle, tint: tint) }.buttonStyle(.plain)
    }
}

struct RoomCard: View {
    let icon: String; let title: String; let subtitle: String; let tint: Color
    var body: some View {
        AppCard {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2.bold()).foregroundStyle(Theme.navy).frame(width: 52, height: 52).background(tint, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                Spacer(); Image(systemName: "chevron.left").foregroundStyle(.secondary)
            }
        }
    }
}

enum RoomType: String { case group, lesson }

struct RoomsHubView: View {
    var body: some View {
        ScreenBackground { ScrollView { VStack(spacing: 16) {
            NavigationLink { RoomLobbyView(type: .group) } label: { RoomCard(icon: "person.3.fill", title: "غرفة جماعية", subtitle: "مذاكرة واختبار جماعي", tint: Theme.teal) }.buttonStyle(.plain)
            NavigationLink { RoomLobbyView(type: .lesson) } label: { RoomCard(icon: "pencil.and.outline", title: "درس مباشر", subtitle: "سبورة وصوت حي", tint: Theme.gold) }.buttonStyle(.plain)
        }.padding() } }
        .navigationTitle("الغرف")
    }
}

struct RoomLobbyView: View {
    let type: RoomType
    @EnvironmentObject private var app: AppState
    @State private var roomCode = ""
    @State private var createdCode: String?
    var title: String { type == .group ? "غرفة جماعية" : "درس مباشر" }
    var body: some View {
        ScreenBackground { ScrollView { VStack(spacing: 18) {
            AppCard { VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: type == .group ? "person.3.fill" : "pencil.and.outline").font(.title3.bold())
                Text("أنشئ جلسة جديدة أو أدخل بكود المضيف.").foregroundStyle(.secondary)
                Button("أنشئ \(title)") { createdCode = String(UUID().uuidString.prefix(5)).uppercased() }.buttonStyle(GoldButtonStyle())
            } }
            AppCard { VStack(alignment: .leading, spacing: 10) {
                Text("الانضمام بكود").font(.headline)
                TextField("كود الغرفة", text: $roomCode).textInputAutocapitalization(.characters).textFieldStyle(.roundedBorder)
                NavigationLink(value: roomCode.uppercased()) { Text("انضم") }.disabled(roomCode.trimmingCharacters(in: .whitespaces).isEmpty).buttonStyle(GoldButtonStyle())
            } }
            if let code = createdCode { NavigationLink { RoomView(type: type, code: code) } label: { Text("تم إنشاء الغرفة: \(code)") }.buttonStyle(GoldButtonStyle()) }
        }.padding() } }
        .navigationTitle(title)
        .navigationDestination(for: String.self) { RoomView(type: type, code: $0) }
    }
}

struct RoomView: View {
    let type: RoomType; let code: String
    @EnvironmentObject private var app: AppState
    @State private var quizStarted = false
    @State private var raisedHand = false
    @State private var participants = ["\u{200F}عبدالله", "Sultan"]
    var body: some View {
        ScreenBackground { ScrollView { VStack(alignment: .leading, spacing: 16) {
            AppCard { HStack { VStack(alignment: .leading) { Text(type == .group ? "غرفة المذاكرة الحية" : "سبورة الشرح المباشرة").font(.headline); Text("الكود: \(code)").foregroundStyle(.secondary) }; Spacer(); Text("👑 المضيف").font(.caption.bold()).padding(8).background(Theme.gold, in: Capsule()).foregroundStyle(Theme.navy) } }
            if type == .lesson { WhiteboardPlaceholder() }
            if quizStarted { QuizPlaceholder() } else { Button(type == .group ? "ابدأ مذاكرة" : "ابدأ اختبار") { quizStarted = true }.buttonStyle(GoldButtonStyle()) }
            AppCard { VStack(alignment: .leading, spacing: 10) {
                Text("👥 المشاركون والنتائج").font(.headline)
                ForEach(participants, id: \.self) { name in HStack { Text(name); Spacer(); Text(quizStarted ? "بانتظار الحل" : "متصل").font(.caption).foregroundStyle(.secondary) } }
                if type == .lesson { Button(raisedHand ? "اخفض يدك" : "ارفع يدك") { raisedHand.toggle() }.buttonStyle(.bordered) }
            } }
        }.padding() } }
        .navigationTitle(code)
    }
}

struct WhiteboardPlaceholder: View {
    var body: some View { AppCard { VStack(spacing: 14) { Image(systemName: "pencil.tip.crop.circle").font(.system(size: 46)).foregroundStyle(Theme.teal); Text("السبورة المباشرة").font(.headline); Text("يستطيع المضيف منح صلاحية الرسم والكتابة للطلاب.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 20) } }
}

struct QuizPlaceholder: View {
    var body: some View { AppCard { VStack(alignment: .leading, spacing: 12) { Text("الاختبار بدأ").font(.title3.bold()); Text("سيظهر ترتيب الطلاب ودرجاتهم هنا بعد التسليم.").foregroundStyle(.secondary); HStack { Text("🥇"); Text("نتائج الاختبار").font(.headline); Spacer(); Text("0/0").foregroundStyle(.secondary) } } } }
}

struct LibraryView: View {
    @State private var books: [String] = []
    @State private var showImporter = false
    @State private var renameBook: String?
    @State private var newName = ""
    var body: some View {
        ScreenBackground { Group {
            if books.isEmpty { ContentUnavailableView("المكتبة", systemImage: "books.vertical", description: Text("أضف كتاب PDF من جهازك للبدء.")) }
            else { List { ForEach(books, id: \.self) { book in HStack { Text(book); Spacer(); Button("إعادة تسمية") { newName = book; renameBook = book }.buttonStyle(.bordered); Button("حذف", role: .destructive) { books.removeAll { $0 == book } }.buttonStyle(.bordered) } }.listRowBackground(Color.clear) }.scrollContentBackground(.hidden) }
        } }
        .navigationTitle("المكتبة")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { showImporter = true } label: { Label("أضف كتاب", systemImage: "plus") } } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in if case .success(let url) = result { books.append(url.deletingPathExtension().lastPathComponent) } }
        .alert("إعادة تسمية الكتاب", isPresented: Binding(get: { renameBook != nil }, set: { if !$0 { renameBook = nil } })) { TextField("اسم الكتاب", text: $newName); Button("إلغاء", role: .cancel) {}; Button("حفظ") { if let old = renameBook, let index = books.firstIndex(of: old) { books[index] = newName }; renameBook = nil } }
    }
}

struct PerformanceView: View {
    var body: some View { ScreenBackground { ScrollView { VStack(alignment: .leading, spacing: 16) { Text("لوحة الأداء").font(.largeTitle.bold()); HStack(spacing: 10) { Stat(title: "سلسلة", value: "0", icon: "flame.fill", color: .orange); Stat(title: "ساعات", value: "0", icon: "clock.fill", color: Theme.teal); Stat(title: "اختبارات", value: "0", icon: "trophy.fill", color: Theme.gold) }; AppCard { VStack(alignment: .leading, spacing: 8) { Text("تقدم الدرجات").font(.headline); ContentUnavailableView("لا توجد نتائج بعد", systemImage: "chart.line.uptrend.xyaxis") } } }.padding() } }.navigationTitle("أدائي") }
}

struct Stat: View { let title: String; let value: String; let icon: String; let color: Color; var body: some View { AppCard { VStack(spacing: 7) { Image(systemName: icon).foregroundStyle(color); Text(value).font(.title2.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) } } }

struct SettingsView: View {
    @Binding var showWelcome: Bool
    @EnvironmentObject private var app: AppState
    @State private var name = ""; @State private var email = ""
    var body: some View {
        ScreenBackground { Form {
            Section("الحساب") { TextField("الاسم", text: $name); TextField("البريد الإلكتروني", text: $email).keyboardType(.emailAddress); Button("حفظ البيانات") { app.saveProfile(name: name, email: email) }.buttonStyle(GoldButtonStyle()) }
            Section("الواجهة") { Picker("المظهر", selection: $app.appearance) { Text("تلقائي").tag(Appearance.system); Text("فاتح").tag(Appearance.light); Text("داكن").tag(Appearance.dark) }.pickerStyle(.segmented) }
            Section("الخصوصية") { NavigationLink("البروفايل والخصوصية") { ProfileView() }; NavigationLink("الأصدقاء") { FriendsView() }; NavigationLink("الأرشيف") { ArchiveView() } }
            Section { Button("تسجيل خروج", role: .destructive) { app.isLoggedIn = false; showWelcome = true } }
        }.scrollContentBackground(.hidden).onAppear { name = app.username; email = app.email } }
        .navigationTitle("الإعدادات")
    }
}

struct ProfileView: View { @EnvironmentObject private var app: AppState; @State private var bio = ""; @State private var school = ""; @State private var isPrivate = false; var body: some View { ScreenBackground { ScrollView { VStack(spacing: 16) { AppCard { VStack(spacing: 10) { Text(String(app.username.prefix(1))).font(.system(size: 42, weight: .bold)).foregroundStyle(Theme.beige).frame(width: 88,height:88).background(Theme.teal, in: Circle()); Text(app.username).font(.title.bold()); if !school.isEmpty { Label(school, systemImage: "graduationcap.fill").foregroundStyle(Theme.teal) }; if !bio.isEmpty { Text(bio).foregroundStyle(.secondary).multilineTextAlignment(.center) } } .frame(maxWidth: .infinity) }; AppCard { VStack(alignment: .leading) { Text("تعديل البروفايل").font(.headline); TextField("نبذة عنك", text: $bio); TextField("اسم المدرسة", text: $school); Toggle("البروفايل خاص بالكامل", isOn: $isPrivate) } } }.padding() } }.navigationTitle("بروفايلي") } }

struct FriendsView: View { @State private var query = ""; @State private var friends = ["Sultan"]; var body: some View { ScreenBackground { List { Section { TextField("ابحث باسم المستخدم", text: $query); Button("إضافة صديق") { if !query.isEmpty { friends.append(query); query = "" } }.buttonStyle(GoldButtonStyle()) }; Section("أصدقاؤك") { ForEach(friends, id: \.self) { Text($0) }.onDelete { friends.remove(atOffsets: $0) } } }.scrollContentBackground(.hidden) }.navigationTitle("الأصدقاء") } }

struct ArchiveView: View { var body: some View { ScreenBackground { ContentUnavailableView("الأرشيف", systemImage: "archivebox", description: Text("ستظهر هنا الغرف والدروس بعد انتهائها.")) }.navigationTitle("الأرشيف") } }
