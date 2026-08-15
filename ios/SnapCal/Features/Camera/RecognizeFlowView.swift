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
    @State private var replacingIndex: Int?
    @State private var showFoodSearch = false
    @State private var showCamera = false
    @State private var scanY: CGFloat = 0

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
            .onChange(of: recognizing) { _, running in
                if running {
                    scanY = -0.45
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        scanY = 0.45
                    }
                } else {
                    scanY = 0
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadAndRecognize(newItem) }
            }
            .sheet(isPresented: $showFoodSearch) {
                if let index = replacingIndex {
                    FoodSearchSheet { food in
                        replaceItem(at: index, with: food)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView { image in
                    Task { await recognize(image) }
                }
            }
        }

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
                // AI 扫描线动效
                if recognizing {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, .brandGreen, .clear],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(height: 3)
                            .shadow(color: .brandGreen.opacity(0.7), radius: 10)
                            .position(x: geo.size.width / 2,
                                      y: geo.size.height * (scanY + 0.5))
                    }
                    .frame(height: 300)
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(recognizing ? "识别中…" : "从相册选择", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.brandGreen)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .disabled(recognizing)

            Button {
                showCamera = true
            } label: {
                Label("拍照", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.brandBlue)
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
                ForEach(Array($items.enumerated()), id: \.element.id) { index, $item in
                    itemRow($item, index: index)
                    if index != items.count - 1 {
                        Divider().overlay(Color.dividerLine)
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

    private func itemRow(_ item: Binding<RecognizeResult.FoodItem>, index: Int) -> some View {
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
                    let old = item.wrappedValue.weightG
                    let newWeight = max(10, old - 10)
                    item.wrappedValue.weightG = newWeight
                    item.wrappedValue.kcal = recalc(kcal: item.wrappedValue.kcal, oldWeight: old, newWeight: newWeight)
                } label: {
                    Image(systemName: "minus").frame(width: 30, height: 30)
                }
                Text("\(item.wrappedValue.weightG)g")
                    .font(.subheadline.bold()).frame(minWidth: 56)
                Button {
                    let old = item.wrappedValue.weightG
                    let newWeight = old + 10
                    item.wrappedValue.weightG = newWeight
                    item.wrappedValue.kcal = recalc(kcal: item.wrappedValue.kcal, oldWeight: old, newWeight: newWeight)
                } label: {
                    Image(systemName: "plus").frame(width: 30, height: 30)
                }
            }
            .background(.weakFill)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(.brandBlue)

            Text("\(item.wrappedValue.kcal)")
                .font(.subheadline.bold())
                .frame(width: 52, alignment: .trailing)

            Button {
                replacingIndex = index
                showFoodSearch = true
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.brandBlue)
            }
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

    /** 用食物库食物替换识别项: 按每100g营养×当前克重计算 */
    private func replaceItem(at index: Int, with food: Food) {
        guard index < items.count else { return }
        let weight = Double(items[index].weightG) / 100.0
        items[index].name = food.name
        items[index].kcal = Int(weight * Double(food.kcalPer100g ?? 0))
        items[index].proteinG = weight * (food.proteinPer100g ?? 0)
        items[index].carbsG = weight * (food.carbsPer100g ?? 0)
        items[index].fatG = weight * (food.fatPer100g ?? 0)
        items[index].confidence = 1.0
        replacingIndex = nil
    }

    /** 按克重比例重算热量: newKcal = kcal * newWeight / oldWeight */
    private func recalc(kcal: Int, oldWeight: Int, newWeight: Int) -> Int {
        max(0, Int(Double(kcal) * Double(newWeight) / Double(max(oldWeight, 1))))
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
            try await uploadAndRecognize(image)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func recognize(_ image: UIImage) async {
        recognizing = true
        defer { recognizing = false }
        selectedImage = image
        do {
            try await uploadAndRecognize(image)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func uploadAndRecognize(_ image: UIImage) async throws {
        guard let jpg = image.jpegData(compressionQuality: 0.8) else {
            errorText = "图片处理失败"
            return
        }
        let r: RecognizeResult = try await api.upload(RecognizeResult.self, path: "/vision/recognize", imageData: jpg)
        resultImage = r.image
        items = r.items
        engine = r.engine
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
            // 写入 Apple 健康
            await HealthKitManager.shared.writeMeal(
                kcal: totalKcal,
                proteinG: totalProtein,
                carbsG: totalCarbs,
                fatG: totalFat,
                at: Date())
            NotificationCenter.default.post(name: .mealSaved, object: nil)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
