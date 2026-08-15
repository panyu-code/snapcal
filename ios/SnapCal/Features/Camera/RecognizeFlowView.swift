import SwiftUI
import PhotosUI

/// 拍照/选图 → AI 识别 → 克重调整 → 保存 (M2 核心链路)
struct RecognizeFlowView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var recognizing = false
    @State private var saving = false
    @State private var resultImage: String?
    @State private var items: [RecognizeResult.FoodItem] = []
    @State private var engine: String?
    @State private var mealType = "LUNCH"
    @State private var errorText: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if items.isEmpty {
                        pickerSection
                    } else {
                        confirmSection
                    }
                    if let errorText {
                        Text(errorText).font(.caption).foregroundStyle(.brandRed)
                    }
                }
                .padding(18)
            }
            .background(Color.pageBG)
            .navigationTitle("拍照记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadAndRecognize(newItem) }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 选图区

    private var pickerSection: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.brandGreen.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .frame(height: 300)
                VStack(spacing: 14) {
                    Text("🍽️").font(.system(size: 64))
                    Text(recognizing ? "AI 正在识别…" : "对准餐盘拍一张")
                        .font(.headline)
                    if recognizing { ProgressView().tint(.brandGreen) }
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(recognizing ? "识别中…" : "选择照片 / 拍照", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.brandGreen)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .disabled(recognizing)
            Spacer(minLength: 40)
        }
    }

    // MARK: - 确认区

    private var confirmSection: some View {
        VStack(spacing: 14) {
            if let image = resultImage, let url = URL(string: image) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color.cardBG.overlay(ProgressView())
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Picker("餐次", selection: $mealType) {
                Text("早餐").tag("BREAKFAST")
                Text("午餐").tag("LUNCH")
                Text("晚餐").tag("DINNER")
                Text("加餐").tag("SNACK")
            }
            .pickerStyle(.segmented)

            // 食物列表 + 克重调整
            VStack(spacing: 0) {
                ForEach($items) { $item in
                    itemRow($item)
                    if item.id != items.last?.id {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
            .cardStyle()

            // 汇总
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("合计 \(totalKcal) kcal").font(.title3.bold()).foregroundStyle(.brandGreen)
                    Text("蛋白质 \(Int(totalProtein))g · 碳水 \(Int(totalCarbs))g · 脂肪 \(Int(totalFat))g")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let engine = engine {
                    Text(engine == "mock" ? "演示识别" : engine).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .cardStyle()

            Button {
                Task { await saveMeal() }
            } label: {
                if saving { ProgressView().tint(.black) }
                else { Text("记入今日\(mealTypeName)").font(.headline) }
            }
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(Color.brandGreen).foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .disabled(saving)
        }
    }

    private func itemRow(_ item: Binding<RecognizeResult.FoodItem>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.wrappedValue.name).font(.subheadline.bold())
                Text("每100g ≈ \(Int(Double(item.wrappedValue.kcal) / Double(max(item.wrappedValue.weightG, 1)) * 100)) kcal")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            // 克重步进器
            HStack(spacing: 0) {
                Button {
                    let newWeight = max(10, item.wrappedValue.weightG - 10)
                    item.wrappedValue.weightG = newWeight
                    item.wrappedValue.kcal = recalc(item.wrappedValue)
                } label: {
                    Image(systemName: "minus").frame(width: 30, height: 30)
                }
                Text("\(item.wrappedValue.weightG)g")
                    .font(.subheadline.bold()).frame(minWidth: 56)
                Button {
                    let newWeight = item.wrappedValue.weightG + 10
                    item.wrappedValue.weightG = newWeight
                    item.wrappedValue.kcal = recalc(item.wrappedValue)
                } label: {
                    Image(systemName: "plus").frame(width: 30, height: 30)
                }
            }
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(.brandBlue)

            Text("\(item.wrappedValue.kcal)")
                .font(.subheadline.bold())
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - 逻辑

    private var totalKcal: Int { items.reduce(0) { $0 + $1.kcal } }
    private var totalProtein: Double { items.reduce(0) { $0 + ($1.proteinG ?? 0) } }
    private var totalCarbs: Double { items.reduce(0) { $0 + ($1.carbsG ?? 0) } }
    private var totalFat: Double { items.reduce(0) { $0 + ($1.fatG ?? 0) } }
    private var mealTypeName: String {
        switch mealType {
        case "BREAKFAST": return "早餐"
        case "DINNER": return "晚餐"
        case "SNACK": return "加餐"
        default: return "午餐"
        }
    }

    /** 按克重比例重算热量 */
    private func recalc(_ item: RecognizeResult.FoodItem) -> Int {
        let ratio = Double(item.weightG) / 100.0
        return Int(ratio * Double(item.kcal) / max(Double(item.weightG), 1) * 100)
    }

    private func loadAndRecognize(_ item: PhotosPickerItem) async {
        recognizing = true
        defer { recognizing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorText = "图片加载失败"
                return
            }
            selectedImage = image
            // 压缩到 jpg
            guard let jpg = image.jpegData(compressionQuality: 0.8) else {
                errorText = "图片处理失败"
                return
            }
            let r: RecognizeResult = try await api.upload(RecognizeResult.self, path: "/vision/recognize", imageData: jpg)
            resultImage = r.image
            items = r.items
            engine = r.engine
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func saveMeal() async {
        guard !items.isEmpty else { return }
        saving = true
        defer { saving = false }
        let req = MealSaveReq(
            mealType: mealType,
            photoUrl: resultImage,
            eatTime: nil,
            items: items.map {
                MealSaveReq.MealSaveItem(
                    foodName: $0.name, weightG: $0.weightG, kcal: $0.kcal,
                    proteinG: $0.proteinG, carbsG: $0.carbsG, fatG: $0.fatG, source: "AI")
            }
        )
        do {
            let _: Meal = try await api.post(path: "/meal", body: req)
            await app.refreshMe()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
