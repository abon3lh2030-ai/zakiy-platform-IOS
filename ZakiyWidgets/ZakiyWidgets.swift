import SwiftUI
import WidgetKit

private enum WidgetColors {
    static let navy = Color(red: 0.106, green: 0.165, blue: 0.290)
    static let darkNavy = Color(red: 0.078, green: 0.094, blue: 0.122)
    static let cream = Color(red: 0.980, green: 0.976, blue: 0.965)
    static let card = Color(red: 0.941, green: 0.933, blue: 0.902)
    static let darkCard = Color(red: 0.110, green: 0.133, blue: 0.173)
    static let gold = Color(red: 1.000, green: 0.788, blue: 0.235)
}

private struct WidgetSnapshot {
    let streak: Int
    let longestStreak: Int
    let studyHours: Double
    let attempts: Int
    let averageScore: Double
    let weakTopic: String?
    let languageCode: String

    static let demo = WidgetSnapshot(streak: 7, longestStreak: 12, studyHours: 4.5, attempts: 18, averageScore: 86, weakTopic: "المفردات", languageCode: "ar")

    static func load() -> WidgetSnapshot {
        let defaults = UserDefaults(suiteName: "group.com.zakiy.platform.shared")
        guard defaults?.object(forKey: "streak") != nil else { return .demo }
        return WidgetSnapshot(
            streak: defaults?.integer(forKey: "streak") ?? 0,
            longestStreak: defaults?.integer(forKey: "longestStreak") ?? 0,
            studyHours: defaults?.double(forKey: "studyHours") ?? 0,
            attempts: defaults?.integer(forKey: "attempts") ?? 0,
            averageScore: defaults?.double(forKey: "averageScore") ?? 0,
            weakTopic: defaults?.string(forKey: "weakTopic"),
            languageCode: defaults?.string(forKey: "languageCode") ?? "ar"
        )
    }

    var isArabic: Bool { languageCode == "ar" }
    var appName: String { isArabic ? "ذكّي" : "zakiy" }
    var startTitle: String { isArabic ? "ابدأ مذاكرة" : "Start studying" }
    var performanceTitle: String { isArabic ? "الأداء" : "Performance" }
    var streakTitle: String { isArabic ? "يوم متتالي" : "day streak" }
    var hoursTitle: String { isArabic ? "ساعات مذاكرة" : "study hours" }
    var attemptsTitle: String { isArabic ? "اختبار" : "quizzes" }
    var weakTitle: String { isArabic ? "راجع اليوم" : "Review today" }
}

private struct ZakiyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct ZakiyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZakiyWidgetEntry {
        ZakiyWidgetEntry(date: .now, snapshot: .demo)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZakiyWidgetEntry) -> Void) {
        completion(ZakiyWidgetEntry(date: .now, snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZakiyWidgetEntry>) -> Void) {
        let entry = ZakiyWidgetEntry(date: .now, snapshot: .load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private struct ZakiyWidgetView: View {
    let entry: ZakiyWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var background: Color { colorScheme == .dark ? WidgetColors.darkNavy : WidgetColors.cream }
    private var card: Color { colorScheme == .dark ? WidgetColors.darkCard : WidgetColors.card }
    private var primary: Color { colorScheme == .dark ? WidgetColors.cream : WidgetColors.navy }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            case .systemLarge: large
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            default: medium
            }
        }
        .containerBackground(for: .widget) { background }
        .environment(\.layoutDirection, entry.snapshot.isArabic ? .rightToLeft : .leftToRight)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption.bold())
                .foregroundStyle(WidgetColors.gold)
            Text(entry.snapshot.appName)
                .font(.caption.bold())
                .foregroundStyle(primary)
            Spacer()
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "flame.fill").foregroundStyle(WidgetColors.gold)
                Text("\(entry.snapshot.streak)").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(primary)
            }
            Text(entry.snapshot.streakTitle).font(.caption2).foregroundStyle(primary.opacity(0.7))
            Spacer(minLength: 0)
            Link(destination: URL(string: "zakiy://solo")!) {
                Label(entry.snapshot.startTitle, systemImage: "book.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(WidgetColors.navy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(WidgetColors.gold, in: Capsule())
            }
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 12) {
            Link(destination: URL(string: "zakiy://solo")!) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(WidgetColors.navy)
                    Text(entry.snapshot.startTitle).font(.headline.bold()).foregroundStyle(WidgetColors.navy)
                    Text(entry.snapshot.isArabic ? "ملخص واختبار وذكاء اصطناعي" : "Summary, quiz & AI").font(.caption2).foregroundStyle(WidgetColors.navy.opacity(0.75))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(14)
                .background(WidgetColors.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 7) {
                header
                statLine(icon: "flame.fill", value: "\(entry.snapshot.streak)", label: entry.snapshot.streakTitle)
                statLine(icon: "clock.fill", value: String(format: "%.1f", entry.snapshot.studyHours), label: entry.snapshot.hoursTitle)
                Link(destination: URL(string: "zakiy://performance")!) {
                    Text(entry.snapshot.performanceTitle).font(.caption.bold()).foregroundStyle(WidgetColors.gold)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(12)
            .background(card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(12)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.snapshot.isArabic ? "ملخصك اليوم" : "Your study at a glance").font(.headline).foregroundStyle(primary)
                    Text(entry.snapshot.isArabic ? "استمر، أنت على الطريق الصحيح" : "Keep going, you are on track").font(.caption).foregroundStyle(primary.opacity(0.65))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(entry.snapshot.streak)").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(WidgetColors.gold)
                    Text(entry.snapshot.streakTitle).font(.caption2).foregroundStyle(primary.opacity(0.7))
                }
            }
            HStack(spacing: 8) {
                largeStat(value: String(format: "%.1f", entry.snapshot.studyHours), label: entry.snapshot.hoursTitle, icon: "clock.fill")
                largeStat(value: "\(entry.snapshot.attempts)", label: entry.snapshot.attemptsTitle, icon: "checkmark.seal.fill")
                largeStat(value: "\(Int(entry.snapshot.averageScore))%", label: entry.snapshot.performanceTitle, icon: "chart.line.uptrend.xyaxis")
            }
            if let weakTopic = entry.snapshot.weakTopic {
                HStack(spacing: 8) {
                    Image(systemName: "target").foregroundStyle(WidgetColors.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.snapshot.weakTitle).font(.caption2).foregroundStyle(primary.opacity(0.65))
                        Text(weakTopic).font(.subheadline.bold()).foregroundStyle(primary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            HStack(spacing: 8) {
                Link(destination: URL(string: "zakiy://solo")!) {
                    Label(entry.snapshot.startTitle, systemImage: "book.fill")
                        .font(.caption.bold()).foregroundStyle(WidgetColors.navy)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(WidgetColors.gold, in: Capsule())
                }
                Link(destination: URL(string: "zakiy://performance")!) {
                    Label(entry.snapshot.performanceTitle, systemImage: "chart.bar.fill")
                        .font(.caption.bold()).foregroundStyle(primary)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(card, in: Capsule())
                }
            }
        }
        .padding(16)
    }

    private var circular: some View {
        Gauge(value: min(Double(entry.snapshot.streak), 30), in: 0...30) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(entry.snapshot.streak)").font(.headline.bold())
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(WidgetColors.gold)
        .widgetLabel { Text(entry.snapshot.streakTitle) }
    }

    private var rectangular: some View {
        Link(destination: URL(string: "zakiy://solo")!) {
            HStack(spacing: 8) {
                Image(systemName: "book.fill").foregroundStyle(WidgetColors.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.snapshot.startTitle).font(.headline)
                    Text("\(entry.snapshot.streak) • \(entry.snapshot.streakTitle)").font(.caption2)
                }
            }
        }
    }

    private var inline: some View {
        Text("\(entry.snapshot.appName)  •  \(entry.snapshot.streak) \(entry.snapshot.streakTitle)")
    }

    private func statLine(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption2).foregroundStyle(WidgetColors.gold)
            Text(value).font(.subheadline.bold()).foregroundStyle(primary)
            Text(label).font(.caption2).foregroundStyle(primary.opacity(0.7))
        }
    }

    private func largeStat(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon).font(.caption).foregroundStyle(WidgetColors.gold)
            Text(value).font(.headline.bold()).foregroundStyle(primary)
            Text(label).font(.caption2).foregroundStyle(primary.opacity(0.65)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

@main
struct ZakiyWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZakiyWidget()
    }
}

struct ZakiyWidget: Widget {
    let kind = "ZakiyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZakiyWidgetProvider()) { entry in
            ZakiyWidgetView(entry: entry)
        }
        .configurationDisplayName("ذكّي / zakiy")
        .description("ابدأ مذاكرتك وتابع أداءك من الشاشة الرئيسية")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
