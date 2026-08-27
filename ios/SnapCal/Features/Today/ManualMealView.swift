import SwiftUI

/// 手动记录餐次: 选类型 + 收藏/常吃快捷添加 + 搜索添加 + 份量编辑 + 备注
struct ManualMealView: View {
    /// 进入时预选的餐次类型
    var initialType: String = mealTypeForNow()

    @Environment(\.dismiss) private var dismiss
    @State private var mealType: String
    @State private var items: [DraftFood] = []
    @State private var note = ""
    @State private var favorites: [Food] = []
    @State private var recents: [Food] = []
    @State private var showSearch = false
    @State private var saving = false
    @State private var loadFailed = false

    init(initialType: String = ManualMealView.mealTypeForNow()) {
        self.initialType = initialType
        _mealType = State(initialValue: initialType)
    }

    /// 按当前时间猜餐次
    static func mealTypeForNow() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10: return "BREAKFAST"
        case 10..<14: return "LUNCH"
        case 14..<21: return "DINNER"
        default: return "SNACK"
        }
    }

    private var totalKcal: Int { items.reduce(0) { $0 + $1.kcal } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    typePicker

                    if !favorites.isEmpty || !recents.isEmpty {
                        quickAddCard
                    }

                    foodListCard

                    noteCard
                }
                .padding(16)
            }
            .background(Color.pageBG)
            .navigationTitle("手动记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving { ProgressView() } else { Text("保存").bold() }
                    }
                    .disabled(items.isEmpty || saving)
                    .accessibilityIdentifier("save-meal")
                }
            }
            .sheet(isPresented: $showSearch) {
                FoodSearchSheet(stayOpen: true) { food in
                    addFood(food)
                }
            }
            .task { await loadQuickPicks() }
        }
    }

    // MARK: - 餐次类型

    private var typePicker: some View {
        HStack(spacing: 8) {
            ForEach(Self.slots, id: \.0) { type, emoji, name in
                Button {
                    mealType = type
                } label: {
                    VStack(spacing: 4) {
                        Text(emoji).font(.title3)
                        Text(name).font(.caption2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(mealType == type ? Color.brandGreen.opacity(0.18) : Color.weakFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(mealType == type ? Color.brandGreen : .clear, lineWidth: 1.5)
                    )
                    .foregroundStyle(mealType == type ? Color.brandGreen : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    static let slots: [(String, String, String)] = [
        ("BREAKFAST", "🥣", "早餐"),
        ("LUNCH", "🍽️", "午餐"),
        ("DINNER", "🍜", "晚餐"),
        ("SNACK", "🍎", "加餐")
    ]

    // MARK: - 收藏 / 常吃

    private var quickAddCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !favorites.isEmpty {
                quickSection(title: "⭐ 收藏", foods: favorites)
            }
            if !recents.isEmpty {
                quickSection(title: "🕘 常吃", foods: recents.filter { r in !items.contains(where: { $0.food.id == r.id }) && !favorites.contains(where: { $0.id == r.id }) })
            }
        }
    }

    private func quickSection(title: String, foods: [Food]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(foods) { food in
                        Button {
                            addFood(food)
                        } label: {
                            HStack(spacing: 5) {
                                Text(food.emoji ?? FoodEmoji.forFood(food.name))
                                Text(food.name).font(.caption)
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.brandGreen)
                            }
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(Capsule().fill(Color.weakFill))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 已添加食物

    private var foodListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("食物明细").font(.subheadline.bold())
                Spacer()
                Button {
                    showSearch = true
                } label: {
                    Label("添加食物", systemImage: "plus.circle.fill")
                        .font(.caption.bold()).foregroundStyle(.brandGreen)
                }
            }
            .padding(.bottom, 10)

            if items.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle")
                        .font(.title2).foregroundStyle(.tertiary)
                    Text("点「添加食物」从 622 种食物库选择")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            } else {
                ForEach(items) { item in
                    draftRow(item)
                    if item.id != items.last?.id {
                        Divider().overlay(Color.dividerLine)
                    }
                }
                // 合计
                HStack {
                    Spacer()
                    Text("合计 \(totalKcal) kcal")
                        .font(.subheadline.bold()).foregroundStyle(.brandGreen)
                }
                .padding(.top, 10)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func draftRow(_ item: DraftFood) -> some View {
        HStack(spacing: 10) {
            Text(item.food.emoji ?? FoodEmoji.forFood(item.food.name))
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.weakFill))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.food.name).font(.subheadline.bold())
                Text("\(item.kcal) kcal · 蛋白\(item.proteinG)g 碳水\(item.carbsG)g 脂肪\(item.fatG)g")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                TextField("100", text: weightBinding(item))
                    .keyboardType(.numberPad)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.trailing)
                    .frame(width: 46)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.weakFill))
                Text("g").font(.caption).foregroundStyle(.secondary)
            }
            Button {
                withAnimation { _ = items.removeAll { $0.id == item.id } }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brandRed.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    // MARK: - 备注

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注 (选填)").font(.subheadline.bold())
            TextField("如: 公司食堂 / 少油", text: $note, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...3)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.weakFill))
        }
        .padding(14)
        .cardStyle()
    }

    // MARK: - 数据

    /// 份量输入绑定 (引用 @State items 中的条目)
    private func weightBinding(_ item: DraftFood) -> Binding<String> {
        Binding(
            get: { items.first(where: { $0.id == item.id })?.weightText ?? "100" },
            set: { newValue in
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].weightText = String(newValue.prefix(5).filter(\.isNumber))
                }
            }
        )
    }

    private func addFood(_ food: Food) {
        // 已存在则跳过
        guard !items.contains(where: { $0.food.id == food.id }) else { return }
        Haptics.light()
        withAnimation { items.append(DraftFood(food: food)) }
    }

    private func loadQuickPicks() async {
        if let favs = try? await APIClient.shared.get([Food].self, path: "/food/favorites") {
            favorites = favs
        }
        if let rec = try? await APIClient.shared.get([Food].self, path: "/food/recent") {
            recents = rec
        }
    }

    private func save() async {
        guard !items.isEmpty else { return }
        saving = true
        defer { saving = false }
        let req = MealSaveReq(
            mealType: mealType,
            photoUrl: nil,
            eatTime: nil,
            note: note.isEmpty ? nil : note,
            items: items.map {
                MealSaveReq.MealSaveItem(foodName: $0.food.name,
                                         weightG: $0.weightG,
                                         kcal: $0.kcal,
                                         proteinG: Double($0.proteinG),
                                         carbsG: Double($0.carbsG),
                                         fatG: Double($0.fatG),
                                         source: "MANUAL")
            }
        )
        do {
            let _: Meal = try await APIClient.shared.post(path: "/meal", body: req)
            Haptics.success()
            NotificationCenter.default.post(name: .mealSaved, object: nil)
            dismiss()
        } catch {
            // 静默, 按钮可重试
        }
    }
}

// MARK: - 草稿条目 (份量变化时按每100g参数重算)

struct DraftFood: Identifiable {
    let id = UUID()
    let food: Food
    var weightText: String = "100"

    var weightG: Int { max(Int(weightText) ?? 0, 0) }
    var kcal: Int { Int((Double(food.kcalPer100g ?? 0) * Double(weightG) / 100).rounded()) }
    var proteinG: Int { Int((Double(food.proteinPer100g ?? 0) * Double(weightG) / 100).rounded()) }
    var carbsG: Int { Int((Double(food.carbsPer100g ?? 0) * Double(weightG) / 100).rounded()) }
    var fatG: Int { Int((Double(food.fatPer100g ?? 0) * Double(weightG) / 100).rounded()) }
}
