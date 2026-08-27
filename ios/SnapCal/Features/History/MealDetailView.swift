import SwiftUI

/// 餐次详情页: 照片 + 食物明细 + 营养汇总 + 编辑(备注/类型/份量) + 删除
struct MealDetailView: View {
    let meal: Meal
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var editing = false
    @State private var editMealType = ""
    @State private var editNote = ""
    @State private var editItems: [EditableItem] = []
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 餐盘照片
                    if let photoUrl = meal.photoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color.cardBG.overlay(ProgressView())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .bottomLeading) {
                            Text("\(meal.mealTypeName) · \(eatTimeText)")
                                .font(.caption.bold())
                                .padding(8)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Text("🍽️").font(.system(size: 40))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(meal.mealTypeName).font(.headline)
                                Text(eatTimeText).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }

                    // 备注 (浏览态)
                    if !editing, let note = meal.note, !note.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "note.text").font(.caption).foregroundStyle(.secondary)
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.weakFill))
                    }

                    // 营养汇总
                    HStack(spacing: 10) {
                        macroCard(label: "热量", value: "\(editing ? editTotalKcal : (meal.totalKcal ?? 0))", unit: "kcal", color: .brandGreen)
                        macroCard(label: "蛋白质", value: String(format: "%.0f", editing ? editTotalProtein : (meal.proteinG ?? 0)), unit: "g", color: .brandBlue)
                        macroCard(label: "碳水", value: String(format: "%.0f", editing ? editTotalCarbs : (meal.carbsG ?? 0)), unit: "g", color: .brandOrange)
                        macroCard(label: "脂肪", value: String(format: "%.0f", editing ? editTotalFat : (meal.fatG ?? 0)), unit: "g", color: .brandRed)
                    }

                    // 食物明细
                    if editing {
                        editorCard
                    } else {
                        itemsCard
                    }

                    // 编辑/删除
                    if !editing {
                        if let onDelete {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("删除这条记录", systemImage: "trash")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity).frame(height: 50)
                                    .background(Color.brandRed.opacity(0.12))
                                    .foregroundStyle(.brandRed)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.pageBG)
            .navigationTitle(editing ? "编辑餐次" : "餐次详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if editing {
                        Button("取消") { editing = false }
                    } else {
                        Button("关闭") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if editing {
                        Button {
                            Task { await saveEdit() }
                        } label: {
                            if saving { ProgressView() } else { Text("保存").bold() }
                        }
                        .disabled(editItems.isEmpty || saving)
                    } else {
                        Button("编辑") { beginEdit() }
                    }
                }
            }
            .confirmationDialog("删除这条记录?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: - 浏览态明细

    private var itemsCard: some View {
        VStack(spacing: 0) {
            if let items = meal.items {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.weakFill))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.foodName).font(.subheadline.bold())
                            Text("\(item.weightG)g · \(item.source == "AI" ? "AI 识别" : "手动")")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(item.kcal ?? 0) kcal")
                            .font(.subheadline.bold())
                            .foregroundStyle(.brandGreen)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    if index != items.count - 1 {
                        Divider().overlay(Color.dividerLine)
                    }
                }
            } else {
                Text("无明细").font(.caption).foregroundStyle(.tertiary)
                    .padding(16)
            }
        }
        .cardStyle()
    }

    // MARK: - 编辑态

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 类型
            HStack(spacing: 8) {
                ForEach(ManualMealView.slots, id: \.0) { type, emoji, name in
                    Button {
                        editMealType = type
                    } label: {
                        HStack(spacing: 4) {
                            Text(emoji)
                            Text(name).font(.caption2.bold())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Capsule().fill(editMealType == type ? Color.brandGreen.opacity(0.18) : Color.weakFill))
                        .foregroundStyle(editMealType == type ? Color.brandGreen : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 备注
            TextField("添加备注 (选填)", text: $editNote, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...2)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.weakFill))

            Divider().overlay(Color.dividerLine)

            // 明细份量
            ForEach(editItems) { item in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.foodName).font(.subheadline.bold())
                        Text("\(item.kcal) kcal").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("g", text: weightBinding(item))
                        .keyboardType(.numberPad)
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 52)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.weakFill))
                    Text("g").font(.caption).foregroundStyle(.secondary)
                    Button {
                        editItems.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.brandRed.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func weightBinding(_ item: EditableItem) -> Binding<String> {
        Binding(
            get: { editItems.first(where: { $0.id == item.id })?.weightText ?? "" },
            set: { newValue in
                if let idx = editItems.firstIndex(where: { $0.id == item.id }) {
                    editItems[idx].weightText = String(newValue.prefix(5).filter(\.isNumber))
                }
            }
        )
    }

    // 编辑态汇总 (按原始每克参数重算)
    private var editTotalKcal: Int { editItems.reduce(0) { $0 + $1.kcal } }
    private var editTotalProtein: Double { editItems.reduce(0) { $0 + $1.proteinG } }
    private var editTotalCarbs: Double { editItems.reduce(0) { $0 + $1.carbsG } }
    private var editTotalFat: Double { editItems.reduce(0) { $0 + $1.fatG } }

    private func beginEdit() {
        editMealType = meal.mealType
        editNote = meal.note ?? ""
        editItems = (meal.items ?? []).map { EditableItem(item: $0) }
        editing = true
    }

    private func saveEdit() async {
        guard let mealId = meal.id, !editItems.isEmpty else { return }
        saving = true
        defer { saving = false }
        struct UpdateReq: Codable {
            let mealType: String
            let note: String
            let items: [Item]
            struct Item: Codable {
                let foodName: String
                let weightG: Int
                let kcal: Int
                let proteinG: Double
                let carbsG: Double
                let fatG: Double
                let source: String
            }
        }
        let req = UpdateReq(
            mealType: editMealType,
            note: editNote,
            items: editItems.map {
                UpdateReq.Item(foodName: $0.foodName, weightG: $0.weightG, kcal: $0.kcal,
                               proteinG: $0.proteinG, carbsG: $0.carbsG, fatG: $0.fatG, source: $0.source)
            })
        do {
            let _: Meal = try await APIClient.shared.put(path: "/meal/\(mealId)", body: req)
            Haptics.success()
            editing = false
            NotificationCenter.default.post(name: .mealSaved, object: nil)
        } catch {
            // 静默
        }
    }

    private var eatTimeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let eatTime = meal.eatTime, let date = fmt.date(from: eatTime) else { return "" }
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    private func macroCard(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundStyle(color)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .cardStyle()
    }
}

// MARK: - 可编辑条目 (按原始 kcal/weight 每克参数缩放)

struct EditableItem: Identifiable {
    let id = UUID()
    let foodName: String
    let source: String
    var weightText: String

    /// 每克营养 (由原始记录推导)
    private let kcalPerG: Double
    private let proteinPerG: Double
    private let carbsPerG: Double
    private let fatPerG: Double

    init(item: Meal.MealItem) {
        foodName = item.foodName
        source = item.source ?? "AI"
        let oldWeight = Double(max(item.weightG, 1))
        weightText = String(item.weightG)
        kcalPerG = Double(item.kcal ?? 0) / oldWeight
        proteinPerG = (item.proteinG ?? 0) / oldWeight
        carbsPerG = (item.carbsG ?? 0) / oldWeight
        fatPerG = (item.fatG ?? 0) / oldWeight
    }

    var weightG: Int { max(Int(weightText) ?? 0, 0) }
    var kcal: Int { Int((kcalPerG * Double(weightG)).rounded()) }
    var proteinG: Double { (proteinPerG * Double(weightG) * 10).rounded() / 10 }
    var carbsG: Double { (carbsPerG * Double(weightG) * 10).rounded() / 10 }
    var fatG: Double { (fatPerG * Double(weightG) * 10).rounded() / 10 }
}
