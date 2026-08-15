import SwiftUI
import Charts

/// 趋势统计页: 真实摄入柱状图 + 体重折线 + 达标统计 (照原型⑤)
struct TrendsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var scope = 0              // 0周 1月
    @State private var intake: [DailyIntake] = []
    @State private var weights: [WeightRecord] = []
    @State private var showWeightSheet = false

    private var user: User? { app.user }
    private var target: Int { user?.dailyKcalTarget ?? 2200 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("范围", selection: $scope) {
                        Text("周").tag(0)
                        Text("月").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: scope) { _, _ in Task { await load() } }

                    statRow
                    intakeChart
                    weightCard
                }
                .padding(.horizontal, 18)
            }
            .refreshable { await load() }
            .background(Color.pageBG)
            .navigationTitle("趋势")
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: .weightSaved)) { _ in
                Task { await load() }
            }
        }
        .sheet(isPresented: $showWeightSheet) {
            WeightRecordView()
        }
    }

    // MARK: - 统计卡

    private var statRow: some View {
        HStack(spacing: 10) {
            statCell(value: "\(Int(avgIntake))", label: "日均摄入", color: .brandGreen)
            statCell(value: weightDelta, label: "体重变化", color: .brandGreen)
            statCell(value: "\(hitDays)/\(intake.count)", label: "达标天数", color: .brandOrange)
        }
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .cardStyle()
    }

    private var avgIntake: Double {
        guard !intake.isEmpty else { return 0 }
        return intake.reduce(0.0) { $0 + Double($1.totalKcal) } / Double(intake.count)
    }

    private var hitDays: Int {
        intake.filter { $0.totalKcal <= target }.count
    }

    private var weightDelta: String {
        guard let first = weights.first?.weightKg, let last = weights.last?.weightKg else { return "—" }
        let delta = last - first
        return String(format: "%+.1fkg", delta)
    }

    // MARK: - 摄入柱状图

    private var intakeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("每日摄入").font(.subheadline.bold())
                Spacer()
                Text("虚线 = 目标 \(target)").font(.caption2).foregroundStyle(.secondary)
            }
            if intake.isEmpty {
                Text("暂无数据").font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if scope == 0 {
                // 周视图: 自适应宽度
                Chart(intake) { day in
                    BarMark(
                        x: .value("日", day.shortLabel),
                        y: .value("kcal", day.totalKcal)
                    )
                    .foregroundStyle(day.totalKcal > target ? Color.brandRed : Color.brandGreen)
                    .cornerRadius(4)
                    .annotation(position: .top, alignment: .center) {
                        Text("\(day.totalKcal)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    RuleMark(y: .value("目标", target))
                        .foregroundStyle(.targetLine)
                        .lineStyle(StrokeStyle(dash: [5, 4]))
                }
                .chartYScale(domain: 0...max(2800, target + 600))
                .frame(height: 150)
            } else {
                // 月视图: 横向滚动(每柱46px), 默认显示最近一周(今天在最右, 无空白), 左滑看更早
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        Chart(intake) { day in
                            BarMark(
                                x: .value("日", day.shortLabel),
                                y: .value("kcal", day.totalKcal)
                            )
                            .foregroundStyle(day.totalKcal > target ? Color.brandRed : Color.brandGreen)
                            .cornerRadius(3)
                            .annotation(position: .top, alignment: .center) {
                                Text("\(day.totalKcal)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            RuleMark(y: .value("目标", target))
                                .foregroundStyle(.targetLine)
                                .lineStyle(StrokeStyle(dash: [5, 4]))
                        }
                        .chartYScale(domain: 0...max(2800, target + 600))
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 6))
                        }
                        .frame(width: CGFloat(intake.count) * 46, height: 150)
                        .id("monthChart")
                    }
                    .task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        proxy.scrollTo("monthChart", anchor: .trailing)
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    // MARK: - 体重卡

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("体重趋势").font(.subheadline.bold())
                Spacer()
                Button {
                    showWeightSheet = true
                } label: {
                    Label("记体重", systemImage: "plus.circle.fill")
                        .font(.caption).foregroundStyle(.brandGreen)
                }
            }
            if weights.count >= 2 {
                Chart(weights) { w in
                    LineMark(
                        x: .value("日期", w.recordDate),
                        y: .value("kg", w.weightKg)
                    )
                    .foregroundStyle(Color.brandBlue)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("日期", w.recordDate),
                        y: .value("kg", w.weightKg)
                    )
                    .foregroundStyle(Color.brandBlue)
                    .annotation(position: .top, alignment: .center) {
                        Text(String(format: "%.1f", w.weightKg))
                            .font(.caption2).foregroundStyle(.brandBlue)
                    }
                }
                .frame(height: 120)
            } else if let w = weights.first {
                Text("当前 \(String(format: "%.1f", w.weightKg)) kg，再记录一次即可看到曲线")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("还没有体重记录，点右上角开始")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }

    // MARK: - 加载

    private func load() async {
        let days = scope == 0 ? 7 : 30
        let iKey = "intake-\(days)"
        let wKey = "weight-\(days)"
        if intake.isEmpty, let cached: [DailyIntake] = CacheStore.shared.load([DailyIntake].self, key: iKey) {
            intake = cached
        }
        if weights.isEmpty, let cached: [WeightRecord] = CacheStore.shared.load([WeightRecord].self, key: wKey) {
            weights = cached
        }
        do {
            let fresh = try await APIClient.shared.get([DailyIntake].self, path: "/stats/daily", query: ["days": "\(days)"])
            intake = fresh
            CacheStore.shared.save(key: iKey, value: fresh)
            let wf = try await APIClient.shared.get([WeightRecord].self, path: "/weight/list", query: ["days": "\(days)"])
            weights = wf
            CacheStore.shared.save(key: wKey, value: wf)
        } catch {
            // 网络失败, 保留缓存
        }
    }
}

// MARK: - 模型

struct DailyIntake: Codable, Identifiable {
    let id = UUID()
    let date: String
    let totalKcal: Int

    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let d = formatter.date(from: date) else { return date }
        let calendar = Calendar.current
        if calendar.isDateInToday(d) { return "今" }
        formatter.dateFormat = "d"
        return formatter.string(from: d)
    }

    enum CodingKeys: String, CodingKey { case date, totalKcal }
}

struct WeightRecord: Codable, Identifiable {
    let id: Int64?
    let userId: Int64?
    let weightKg: Double
    let recordDate: String
}

// MARK: - 体重记录弹窗

struct WeightRecordView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("⚖️").font(.system(size: 48))
                Text("记录今日体重").font(.headline)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("65.0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 140)
                    Text("kg").foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView().tint(.black) }
                    else { Text("保存").font(.headline) }
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.brandGreen).foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .disabled(saving || weightText.isEmpty)
            }
            .padding(24)
            .background(Color.pageBG)
            .navigationTitle("记录体重")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }

        .onAppear {
            weightText = app.user?.currentWeightKg.map { String(format: "%.1f", $0) } ?? ""
        }
    }

    private func save() async {
        guard let weight = Double(weightText), weight > 20, weight < 400 else { return }
        saving = true
        defer { saving = false }
        struct Body: Codable { let weightKg: Double }
        do {
            try await APIClient.shared.postVoid(path: "/weight", body: Body(weightKg: weight))
            await app.refreshMe()
            NotificationCenter.default.post(name: .weightSaved, object: nil)
            dismiss()
        } catch {
            // 拦截器无提示, 静默
        }
    }
}

extension Notification.Name {
    static let weightSaved = Notification.Name("SnapCalWeightSaved")
}
