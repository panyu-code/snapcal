import SwiftUI

/// 食物库浏览页: 分类筛选 + 实时搜索 + 分页列表 (查看营养参数)
struct FoodLibraryView: View {
    @State private var categories: [String] = []
    @State private var selectedCategory: String?
    @State private var keyword = ""
    @State private var foods: [Food] = []
    @State private var total = 0
    @State private var page = 1
    @State private var loading = false
    @State private var searchTask: Task<Void, Never>?

    private let pageSize = 50

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框 (输入即搜, 300ms 防抖)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索食物", text: $keyword)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onChange(of: keyword) { _, _ in scheduleSearch() }
                        .onSubmit { Task { await resetAndLoad() } }
                    if loading {
                        ProgressView().controlSize(.small)
                    }
                    if !keyword.isEmpty {
                        Button { keyword = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.weakFill))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // 分类横向筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(label: "全部", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                            Task { await resetAndLoad() }
                        }
                        ForEach(categories, id: \.self) { cat in
                            categoryChip(label: cat, isSelected: selectedCategory == cat) {
                                selectedCategory = cat
                                Task { await resetAndLoad() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // 列表
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(foods) { food in
                            foodRow(food)
                        }
                        // 加载更多
                        if foods.count < total {
                            Button {
                                Task { await loadMore() }
                            } label: {
                                if loading { ProgressView().padding() }
                                else { Text("加载更多 (\(foods.count)/\(total))").font(.caption).foregroundStyle(.secondary).padding() }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .background(Color.pageBG)
                .overlay {
                    if !loading && !keyword.isEmpty && total == 0 {
                        ContentUnavailableView("没有找到相关食物", systemImage: "magnifyingglass",
                                               description: Text("换个关键词试试"))
                    }
                }
            }
            .background(Color.pageBG)
            .navigationTitle("食物库")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadCategories()
                await resetAndLoad()
            }
        }
    }

    private func categoryChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 13).padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? Color.brandGreen : Color.weakFill))
                .foregroundStyle(isSelected ? Color.black : Color.primary)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .buttonStyle(.plain)
    }

    private func foodRow(_ food: Food) -> some View {
        HStack(spacing: 12) {
            Text(food.emoji ?? FoodEmoji.forFood(food.name))
                .font(.title3)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.weakFill))
            VStack(alignment: .leading, spacing: 3) {
                Text.highlighted(food.name, keyword: keyword).font(.subheadline.bold())
                Text("蛋白 \(food.proteinPer100g ?? 0)g · 碳水 \(food.carbsPer100g ?? 0)g · 脂肪 \(food.fatPer100g ?? 0)g")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(food.kcalPer100g ?? 0)").font(.headline).foregroundStyle(.brandGreen)
                Text("kcal/100g").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(11)
        .cardStyle()
    }


    private func loadCategories() async {
        do {
            categories = try await APIClient.shared.get([String].self, path: "/food/categories")
        } catch {
            categories = []
        }
    }

    /// 输入防抖: 停止输入 300ms 后自动搜索 (抖音式)
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await resetAndLoad()
        }
    }

    private func resetAndLoad() async {
        page = 1
        foods = []
        await loadPage()
    }

    private func loadMore() async {
        page += 1
        await loadPage()
    }

    private func loadPage() async {
        loading = true
        defer { loading = false }
        struct PageResp: Codable {
            let records: [Food]
            let total: Int
        }
        let kw = keyword, cat = selectedCategory, reqPage = page
        var query: [String: String] = ["current": "\(reqPage)", "size": "\(pageSize)"]
        if !kw.isEmpty { query["kw"] = kw }
        if let cat { query["category"] = cat }
        do {
            let resp: PageResp = try await APIClient.shared.get(PageResp.self, path: "/food/list", query: query)
            // 输入/筛选已变, 丢弃过期响应 (防旧结果覆盖新搜索)
            guard kw == keyword, cat == selectedCategory else { return }
            if reqPage == 1 { foods = resp.records } else { foods.append(contentsOf: resp.records) }
            total = resp.total
        } catch {
            // 静默
        }
    }
}
