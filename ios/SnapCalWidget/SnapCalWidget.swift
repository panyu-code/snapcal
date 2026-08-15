import WidgetKit
import SwiftUI

/// App 与 Widget 共享数据 (通过 App Group UserDefaults)
struct TodaySnapshot {
    let eaten: Int
    let target: Int

    static let sharedDefaults = UserDefaults(suiteName: "group.com.yupan.snapcal")!

    static func load() -> TodaySnapshot {
        TodaySnapshot(
            eaten: sharedDefaults.integer(forKey: "todayEaten"),
            target: max(sharedDefaults.integer(forKey: "todayTarget"), 1)
        )
    }

    var remaining: Int { max(target - eaten, 0) }
    var progress: Double {
        target > 0 ? min(Double(eaten) / Double(target), 1) : 0
    }
}

// MARK: - Timeline

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: TodaySnapshot(eaten: 354, target: 2200))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: TodaySnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: .now, snapshot: TodaySnapshot.load())
        let next = Calendar.current.date(byAdding: .minute, value: 20, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot
}

// MARK: - View

struct SnapCalWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(red: 0.086, green: 0.106, blue: 0.149).gradient)
            VStack(spacing: 6) {
                Text("📸 SnapCal").font(.caption2).foregroundStyle(.white.opacity(0.7))
                ZStack {
                    Circle().stroke(.white.opacity(0.12), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: entry.snapshot.progress)
                        .stroke(Color(red: 0.20, green: 0.83, blue: 0.60),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(entry.snapshot.remaining)").font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("剩余").font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(width: 74, height: 74)
                Text("已吃 \(entry.snapshot.eaten) / \(entry.snapshot.target)")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            smallView
            VStack(alignment: .leading, spacing: 8) {
                Text("今日热量").font(.headline).foregroundStyle(.white)
                Text("已摄入 \(entry.snapshot.eaten) kcal")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                Text("目标 \(entry.snapshot.target) kcal")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                Text(entry.snapshot.remaining > 0 ? "还能吃 \(entry.snapshot.remaining) kcal" : "今日已超")
                    .font(.caption.bold())
                    .foregroundStyle(entry.snapshot.remaining > 0
                        ? Color(red: 0.20, green: 0.83, blue: 0.60)
                        : Color(red: 0.97, green: 0.43, blue: 0.43))
            }
            Spacer()
        }
        .padding()
        .background(Color(red: 0.086, green: 0.106, blue: 0.149).gradient)
    }
}

// MARK: - Bundle

@main
struct SnapCalWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnapCalWidget()
    }
}

struct SnapCalWidget: Widget {
    let kind = "SnapCalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            SnapCalWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.086, green: 0.106, blue: 0.149)
                }
        }
        .configurationDisplayName("今日热量")
        .description("查看今日已摄入和剩余热量")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
