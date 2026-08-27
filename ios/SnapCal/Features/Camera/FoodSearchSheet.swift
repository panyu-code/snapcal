import SwiftUI

/// 食物库搜索弹窗 (识别错了替换用 / 手动记录连续添加, 输入即搜 + 关键词高亮 + 收藏)
struct FoodSearchSheet: View {
    let onSelect: (Food) -> Void
    /// 连续添加模式: 选中后不关闭弹窗
    var stayOpen = false

    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var results: [Food] = []
    @State private var loading = false
    @State private var searchTask: Task<Void, Never>?
    @State private var favoredIds: Set<Int64> = []
    @State private var favTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框 (输入即搜, 300ms 防抖)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索食物名称", text: $keyword)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onChange(of: keyword) { _, _ in scheduleSearch() }
                        .onSubmit { Task { await search() } }
                    if loading {
                        ProgressView().controlSize(.small)
                    }
                    if !keyword.isEmpty {
                        Button { clearKeyword() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.weakFill))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if keyword.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if !favoredFoods.isEmpty {
                                Text("⭐ 我的收藏").font(.caption.bold()).foregroundStyle(.secondary).padding(.top, 6)
                                ForEach(favoredFoods) { food in
                                    foodRow(food)
                                }
                            }
                            Text("输入食物名称, 实时匹配，如「鸡胸肉」「米饭」")
                                .font(.caption).foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                        }
                        .padding(.horizontal, 16)
                    }
                } else if loading && results.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    ContentUnavailableView("没有找到相关食物", systemImage: "magnifyingglass",
                                           description: Text("换个关键词试试"))
                    Spacer()
                } else {
                    List(results) { food in
                        foodRow(food)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.pageBG)
            .navigationTitle(stayOpen ? "添加食物" : "替换食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(stayOpen ? "完成" : "取消") { dismiss() }
                }
            }
            .task { await loadFavorites() }
        }
    }

    private var favoredFoods: [Food] {
        results.filter { favoredIds.contains($0.id) }
    }

    private func foodRow(_ food: Food) -> some View {
        Button {
            onSelect(food)
            if !stayOpen { dismiss() }
        } label: {
            HStack {
                Text(food.emoji ?? FoodEmoji.forFood(food.name)).font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text.highlighted(food.name, keyword: keyword).font(.subheadline.bold())
                    Text("\(food.kcalPer100g ?? 0) kcal / 100g · " +
                         "蛋白 \(food.proteinPer100g ?? 0)g · " +
                         "碳水 \(food.carbsPer100g ?? 0)g · " +
                         "脂肪 \(food.fatPer100g ?? 0)g")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if let category = food.category, keyword.isEmpty {
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.weakFill))
                        .foregroundStyle(.secondary)
                }
                // 收藏星标
                Button {
                    toggleFavorite(food)
                } label: {
                    Image(systemName: favoredIds.contains(food.id) ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle(favoredIds.contains(food.id) ? Color.orange : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 收藏

    private func loadFavorites() async {
        if let favs = try? await APIClient.shared.get([Food].self, path: "/food/favorites") {
            favoredIds = Set(favs.map(\.id))
        }
    }

    private func toggleFavorite(_ food: Food) {
        Haptics.light()
        let wasFavored = favoredIds.contains(food.id)
        if wasFavored { favoredIds.remove(food.id) } else { favoredIds.insert(food.id) }
        struct Resp: Codable { let favored: Bool }
        favTask?.cancel()
        favTask = Task {
            let resp: Resp? = try? await APIClient.shared.post(path: "/food/favorites/\(food.id)/toggle",
                                                               body: EmptyPayload())
            if let resp {
                // 以服务端结果为准
                if resp.favored { favoredIds.insert(food.id) } else { favoredIds.remove(food.id) }
            } else {
                // 失败回滚
                if wasFavored { favoredIds.insert(food.id) } else { favoredIds.remove(food.id) }
            }
        }
    }

    // MARK: - 搜索

    private func clearKeyword() {
        searchTask?.cancel()
        keyword = ""
        results = []
        loading = false
    }

    /// 输入防抖: 停止输入 300ms 后自动搜索
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    private func search() async {
        guard !keyword.isEmpty else { return }
        loading = true
        defer { loading = false }
        let kw = keyword
        do {
            let fresh = try await APIClient.shared.get([Food].self, path: "/food/search", query: ["kw": kw])
            guard kw == keyword else { return }   // 输入已变, 丢弃过期响应
            results = fresh
        } catch {
            if kw == keyword { results = [] }
        }
    }
}
