import SwiftUI

/// 饮食记录页: 最近 7 天按日分组流水 + 每日小计 + 删除 (照原型④)
struct HistoryView: View {
    @State private var days: [String: [Meal]] = [:]
    @State private var loading = false
    @State private var selectedMeal: Meal?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedDays, id: \.self) { dateKey in
                        daySection(dateKey: dateKey, meals: days[dateKey] ?? [])
                    }
                }
                .padding(.horizontal, 18)
            }
            .refreshable { await load() }
            .background(Color.pageBG)
            .navigationTitle("饮食记录")
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .mealSaved)) { _ in
                Task { await load() }
            }
            .sheet(item: $selectedMeal) { meal in
                MealDetailView(meal: meal) {
                    Task { await delete(meal) }
                }
            }
            .overlay {
                if !loading && days.values.allSatisfy({ $0.isEmpty }) {
                    ContentUnavailableView(
                        "还没有记录",
                        systemImage: "fork.knife",
                        description: Text("点右下角相机按钮，拍下第一餐吧")
                    )
                }
            }
        }
    }

    private var sortedDays: [String] {
        days.keys.sorted(by: >)   // 日期倒序, 最近在前
    }

    private func daySection(dateKey: String, meals: [Meal]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayTitle(dateKey)).font(.subheadline.bold())
                Spacer()
                Text("共 \(meals.reduce(0) { $0 + ($1.totalKcal ?? 0) }) kcal")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.leading, 4)

            ForEach(meals) { meal in
                mealCard(meal)
                    .onTapGesture { selectedMeal = meal }
            }
        }
    }

    private func mealCard(_ meal: Meal) -> some View {
        HStack(spacing: 12) {
            Text(mealEmoji(meal.mealType)).font(.title2)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 12).fill(.weakFill))

            VStack(alignment: .leading, spacing: 5) {
                Text(meal.mealTypeName).font(.subheadline.bold())
                if let items = meal.items, !items.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(items.prefix(4)) { item in
                            Text("\(item.foodName) \(item.weightG)g")
                                .font(.caption2)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.weakFill))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(meal.totalKcal ?? 0)").font(.headline)
                Text("kcal").font(.caption2).foregroundStyle(.secondary)
            }
            // 详情入口提示
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .cardStyle()
    }

    private func mealEmoji(_ type: String) -> String {
        switch type {
        case "BREAKFAST": return "🥣"
        case "LUNCH": return "🍱"
        case "DINNER": return "🍜"
        default: return "🍎"
        }
    }

    private func dayTitle(_ dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return dateKey }

        let today = Calendar.current.isDateInToday(date)
        let yesterday = Calendar.current.isDateInYesterday(date)
        formatter.dateFormat = "M月d日 EEEE"
        let base = formatter.string(from: date)
        if today { return "今天 · \(base)" }
        if yesterday { return "昨天 · \(base)" }
        return base
    }

    private func load() async {
        loading = true
        defer { loading = false }
        if days.isEmpty, let cached: [String: [Meal]] = CacheStore.shared.load([String: [Meal]].self, key: "meals-range-7") {
            days = cached
        }
        do {
            let fresh = try await APIClient.shared.get([String: [Meal]].self, path: "/meal/range", query: ["days": "7"])
            days = fresh
            CacheStore.shared.save(key: "meals-range-7", value: fresh)
        } catch {
            // 网络失败, 保留缓存
        }
    }

    private func delete(_ meal: Meal) async {
        guard let id = meal.id else { return }
        do {
            try await APIClient.shared.delete(path: "/meal/\(id)")
            await load()
            NotificationCenter.default.post(name: .mealSaved, object: nil)  // 联动今日页
        } catch {
            // 静默
        }
    }
}
