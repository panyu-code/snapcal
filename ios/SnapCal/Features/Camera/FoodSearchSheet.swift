import SwiftUI

/// 食物库搜索弹窗 (识别错了替换用)
struct FoodSearchSheet: View {
    let onSelect: (Food) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var results: [Food] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索食物名称", text: $keyword)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                    if !keyword.isEmpty {
                        Button { keyword = ""; results = [] } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.weakFill))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if loading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if keyword.isEmpty {
                    Spacer()
                    Text("输入食物名称搜索，如「鸡胸肉」「米饭」")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    ContentUnavailableView("没有找到相关食物", systemImage: "magnifyingglass")
                    Spacer()
                } else {
                    List(results) { food in
                        Button {
                            onSelect(food)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(food.name).font(.subheadline.bold())
                                    Text("\(food.kcalPer100g ?? 0) kcal / 100g · " +
                                         "蛋白 \(food.proteinPer100g ?? 0)g · " +
                                         "碳水 \(food.carbsPer100g ?? 0)g · " +
                                         "脂肪 \(food.fatPer100g ?? 0)g")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let category = food.category {
                                    Text(category)
                                        .font(.caption2)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.weakFill))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.pageBG)
            .navigationTitle("替换食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        guard !keyword.isEmpty else { return }
        loading = true
        defer { loading = false }
        do {
            results = try await APIClient.shared.get([Food].self, path: "/food/search", query: ["kw": keyword])
        } catch {
            results = []
        }
    }
}
