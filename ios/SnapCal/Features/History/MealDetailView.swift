import SwiftUI

/// 餐次详情页: 照片 + 食物明细 + 营养汇总
struct MealDetailView: View {
    let meal: Meal
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

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

                    // 营养汇总
                    HStack(spacing: 10) {
                        macroCard(label: "热量", value: "\(meal.totalKcal ?? 0)", unit: "kcal", color: .brandGreen)
                        macroCard(label: "蛋白质", value: String(format: "%.0f", meal.proteinG ?? 0), unit: "g", color: .brandBlue)
                        macroCard(label: "碳水", value: String(format: "%.0f", meal.carbsG ?? 0), unit: "g", color: .brandOrange)
                        macroCard(label: "脂肪", value: String(format: "%.0f", meal.fatG ?? 0), unit: "g", color: .brandRed)
                    }

                    // 食物明细
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

                    // 删除按钮
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
                .padding(18)
            }
            .background(Color.pageBG)
            .navigationTitle("餐次详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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
