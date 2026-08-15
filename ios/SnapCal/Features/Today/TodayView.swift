import SwiftUI

/// 今日首页: 卡路里圆环 + 三大营养素 + 餐次列表 (照原型①)
struct TodayView: View {
    @EnvironmentObject private var app: AppModel
    @State private var meals: [Meal] = []
    @State private var loading = false

    private var user: User? { app.user }
    private var target: Int { user?.dailyKcalTarget ?? 2200 }
    private var eaten: Int { meals.reduce(0) { $0 + ($1.totalKcal ?? 0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    CalorieRing(eaten: eaten, target: target)
                    MacroCards(eaten: eaten, target: target)
                    mealList
                    burnCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .refreshable { await loadMeals() }
            .background(Color.pageBG)
            .navigationTitle("今日概览")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadMeals() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.todayText).font(.subheadline).foregroundStyle(.secondary)
                Text(user?.targetTypeName ?? "减脂中")
                    .font(.caption.bold())
                    .foregroundStyle(.brandGreen)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.brandGreen.opacity(0.15)))
            }
            Spacer()
            Image(systemName: "bell").foregroundStyle(.secondary)
        }
    }

    private var mealList: some View {
        VStack(spacing: 0) {
            ForEach(Self.mealSlots, id: \.0) { type, emoji, name in
                let list = meals.filter { $0.mealType == type }
                mealRow(emoji: emoji, name: name,
                        desc: list.isEmpty ? "拍一张照片即可" : "已记 \(list.count) 项",
                        kcal: list.isEmpty ? nil : list.reduce(0) { $0 + ($1.totalKcal ?? 0) })
                if type != "SNACK" {
                    Divider().overlay(Color.white.opacity(0.06))
                }
            }
        }
        .padding(.vertical, 6)
        .cardStyle()
    }

    private static let mealSlots: [(String, String, String)] = [
        ("BREAKFAST", "🥣", "早餐"),
        ("LUNCH", "🍽️", "午餐"),
        ("DINNER", "🍜", "晚餐"),
        ("SNACK", "🍎", "加餐")
    ]

    private func mealRow(emoji: String, name: String, desc: String, kcal: Int?) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title3)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline.bold())
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let kcal {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(kcal)").font(.headline)
                    Text("kcal").font(.caption2).foregroundStyle(.secondary)
                }
                .foregroundStyle(.brandGreen)
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var burnCard: some View {
        HStack(spacing: 12) {
            Text("🔥").font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text("已消耗 1,846 kcal").font(.subheadline.bold())
                Text("步数 8,421 · 运动 32 分钟")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("缺口 \(max(target - eaten, 0))")
                .font(.caption.bold()).foregroundStyle(.brandGreen)
        }
        .padding(14)
        .cardStyle()
        .opacity(0.5) // M4 接 HealthKit 后启用
    }

    private func loadMeals() async {
        loading = true
        defer { loading = false }
        do {
            meals = try await APIClient.shared.get([Meal].self, path: "/meal/day")
        } catch {
            // 静默失败, 保留旧数据
        }
    }

    private static var todayText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: Date())
    }
}

// MARK: - 卡路里圆环

struct CalorieRing: View {
    let eaten: Int
    let target: Int

    private var progress: Double {
        min(Double(eaten) / Double(max(target, 1)), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [.brandGreen, Color(hex: 0x059669)], center: .center),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)

            VStack(spacing: 4) {
                Text("\(eaten)").font(.system(size: 42, weight: .heavy, design: .rounded))
                Text("/ \(target) kcal").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(width: 200, height: 200)
        .padding(.vertical, 8)
    }
}

// MARK: - 三大营养素

struct MacroCards: View {
    let eaten: Int
    let target: Int

    private var macros: [(String, Double, Int, Color)] {
        let ratio = Double(eaten) / Double(max(target, 1))
        let t = Double(target)
        return [
            ("蛋白质", 0.25 * t * ratio, Int(0.25 * t), .brandBlue),
            ("碳水", 0.50 * t * ratio, Int(0.50 * t), .brandOrange),
            ("脂肪", 0.25 * t * ratio * 0.45, Int(0.27 * t), .brandRed)
        ]
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(macros, id: \.0) { name, value, cap, color in
                VStack(spacing: 7) {
                    Text("\(Int(value))g").font(.headline).foregroundStyle(color)
                    Text("\(name) \(Int(value))/\(cap)g")
                        .font(.caption2).foregroundStyle(.secondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(color)
                                .frame(width: max(6, geo.size.width * min(value / Double(max(cap, 1)), 1)))
                        }
                    }
                    .frame(height: 5)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .cardStyle()
    }
}

// MARK: - 卡片样式

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardBG))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06)))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}
