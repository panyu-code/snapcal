import SwiftUI
import Charts

/// 趋势统计页 (M4 接数据, 先用演示数据展示图表能力)
struct TrendsView: View {
    @State private var scope = 0 // 0周 1月

    private struct DayValue: Identifiable {
        let id = UUID()
        let label: String
        let kcal: Int
        var over: Bool { kcal > 2200 }
    }

    private var week: [DayValue] {
        [("一", 2010), ("二", 1745), ("三", 2530), ("四", 1890),
         ("五", 1620), ("六", 2210), ("日", 1920)]
            .map { DayValue(label: $0.0, kcal: $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("范围", selection: $scope) {
                        Text("周").tag(0)
                        Text("月").tag(1)
                    }
                    .pickerStyle(.segmented)

                    statRow
                    intakeChart
                    weightCard
                }
                .padding(.horizontal, 18)
            }
            .background(Color.pageBG)
            .navigationTitle("趋势")
        }
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            statCell(value: "1,846", label: "日均摄入", color: .brandGreen)
            statCell(value: "-0.4kg", label: "本周体重", color: .brandGreen)
            statCell(value: "5/7", label: "达标天数", color: .brandOrange)
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

    private var intakeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("每日摄入").font(.subheadline.bold())
                Spacer()
                Text("虚线 = 目标 2200").font(.caption2).foregroundStyle(.secondary)
            }
            Chart(week) { day in
                BarMark(
                    x: .value("日", day.label),
                    y: .value("kcal", day.kcal)
                )
                .foregroundStyle(day.over ? Color.brandRed : Color.brandGreen)
                .cornerRadius(4)
                RuleMark(y: .value("目标", 2200))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineStyle(StrokeStyle(dash: [5, 4]))
            }
            .chartYScale(domain: 0...2800)
            .frame(height: 150)
        }
        .padding(14)
        .cardStyle()
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("体重趋势").font(.subheadline.bold())
                Spacer()
                Text("65.2 → 63.9 kg").font(.caption2).foregroundStyle(.secondary)
            }
            Text("M4 接入真实体重记录")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }
}
