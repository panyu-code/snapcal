import SwiftUI

/// 今日首页: 卡路里圆环 + 三大营养素 + 餐次列表 + 饮水 + 消耗 (照原型①)
struct TodayView: View {
    @EnvironmentObject private var app: AppModel
    @State private var meals: [Meal] = []
    @State private var loading = false
    @State private var steps = 0
    @State private var activeEnergy = 0
    @State private var water = WaterToday(date: "", totalMl: 0, goalMl: 2000)
    @State private var showManualMeal = false
    @State private var manualPresetType = "BREAKFAST"

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
                    WaterCardView(water: $water)
                    burnCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .refreshable { await loadMeals(); await loadWater() }
            .background(Color.pageBG)
            .navigationTitle("今日概览")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        manualPresetType = ManualMealView.mealTypeForNow()
                        showManualMeal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.brandGreen)
                    }
                    .accessibilityIdentifier("add-meal")
                }
            }
            .task {
                await loadMeals()
                await loadWater()
                await loadHealth()
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealSaved)) { _ in
                Task { await loadMeals() }
            }
            .sheet(isPresented: $showManualMeal) {
                ManualMealView(initialType: manualPresetType)
            }
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
                Button {
                    manualPresetType = type
                    showManualMeal = true
                } label: {
                    mealRow(emoji: emoji, name: name,
                            desc: list.isEmpty ? "点击拍照或手动记录" : "已记 \(list.count) 项",
                            kcal: list.isEmpty ? nil : list.reduce(0) { $0 + ($1.totalKcal ?? 0) })
                }
                .buttonStyle(.plain)
                if type != "SNACK" {
                    Divider().overlay(Color.dividerLine)
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
                .background(RoundedRectangle(cornerRadius: 12).fill(.weakFill))
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
                Text("已消耗 \(activeEnergy) kcal").font(.subheadline.bold())
                Text("步数 \(steps) · 来自 Apple 健康")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("缺口 \(max(target - eaten + activeEnergy, 0))")
                .font(.caption.bold()).foregroundStyle(.brandGreen)
        }
        .padding(14)
        .cardStyle()
    }

    private func loadMeals() async {
        loading = true
        defer { loading = false }
        // 离线: 先读缓存
        let key = "meals-\(Self.todayKey)"
        if meals.isEmpty, let cached: [Meal] = CacheStore.shared.load([Meal].self, key: key) {
            meals = cached
        }
        do {
            let fresh = try await APIClient.shared.get([Meal].self, path: "/meal/day")
            meals = fresh
            CacheStore.shared.save(key: key, value: fresh)
        } catch {
            // 网络失败, 保留缓存数据
        }
    }

    private func loadHealth() async {
        await HealthKitManager.shared.requestAuthorization()
        steps = await HealthKitManager.shared.todayStepCount()
        activeEnergy = await HealthKitManager.shared.todayActiveEnergy()
    }

    private func loadWater() async {
        if let fresh = try? await APIClient.shared.get(WaterToday.self, path: "/water/today") {
            water = fresh
        }
    }

    private static var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private static var todayText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt.string(from: Date())
    }
}

// MARK: - 饮水卡片

struct WaterCardView: View {
    @Binding var water: WaterToday
    @State private var adding = false

    private var progress: Double {
        min(Double(water.totalMl) / Double(max(water.goalMl, 1)), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("💧").font(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日饮水").font(.subheadline.bold())
                    Text("\(water.totalMl) / \(water.goalMl) ml")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if water.totalMl >= water.goalMl {
                    Text("已达标 🎉").font(.caption.bold()).foregroundStyle(.brandBlue)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.weakFill)
                    Capsule().fill(
                        LinearGradient(colors: [.brandBlue, Color(red: 0.3, green: 0.7, blue: 0.95)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(8, geo.size.width * progress))
                    .animation(.easeInOut(duration: 0.4), value: water.totalMl)
                }
            }
            .frame(height: 8)
            HStack(spacing: 8) {
                quickButton("＋200", ml: 200)
                quickButton("＋500", ml: 500)
                Spacer()
                if water.totalMl > 0 {
                    Button {
                        Task { await add(-min(200, water.totalMl)) }
                    } label: {
                        Text("撤销 200")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .disabled(adding)
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func quickButton(_ label: String, ml: Int) -> some View {
        Button {
            Task { await add(ml) }
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(Color.brandBlue.opacity(0.14)))
                .foregroundStyle(.brandBlue)
        }
        .disabled(adding)
        .buttonStyle(.plain)
    }

    private func add(_ ml: Int) async {
        adding = true
        defer { adding = false }
        struct Body: Codable { let amountMl: Int }
        if let fresh: WaterToday = try? await APIClient.shared.post(path: "/water", body: Body(amountMl: ml)) {
            water = fresh
            Haptics.light()
        }
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
                .stroke(.weakFill, lineWidth: 18)
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
                            Capsule().fill(.weakFill)
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
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.dividerLine))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}
