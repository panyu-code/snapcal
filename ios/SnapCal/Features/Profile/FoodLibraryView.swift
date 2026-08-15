import SwiftUI

/// 食物库浏览页: 分类筛选 + 搜索 + 分页列表 (查看营养参数)
struct FoodLibraryView: View {
    @State private var categories: [String] = []
    @State private var selectedCategory: String?
    @State private var keyword = ""
    @State private var foods: [Food] = []
    @State private var total = 0
    @State private var page = 1
    @State private var loading = false

    private let pageSize = 50

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索食物", text: $keyword)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await resetAndLoad() } }
                    if !keyword.isEmpty {
                        Button { keyword = ""; Task { await resetAndLoad() } } label: {
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
                Text(food.name).font(.subheadline.bold())
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
        var query: [String: String] = ["current": "\(page)", "size": "\(pageSize)"]
        if !keyword.isEmpty { query["kw"] = keyword }
        if let cat = selectedCategory { query["category"] = cat }
        do {
            let resp: PageResp = try await APIClient.shared.get(PageResp.self, path: "/food/list", query: query)
            foods.append(contentsOf: resp.records)
            total = resp.total
        } catch {
            // 静默
        }
    }
}
