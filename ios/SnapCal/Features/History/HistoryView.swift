import SwiftUI

/// 饮食记录页 (M3 接数据, 先占位)
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    daySection(title: "今天", total: nil)
                    daySection(title: "昨天", total: "共 1,982 kcal")
                }
                .padding(.horizontal, 18)
            }
            .background(Color.pageBG)
            .navigationTitle("饮食记录")
        }
    }

    private func daySection(title: String, total: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title + (total.map { " · \($0)" } ?? ""))
                .font(.caption).foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 10) {
                logCard(emoji: "🥣", name: "早餐 · 待记录", tags: ["拍照记录"], kcal: nil)
                logCard(emoji: "🍱", name: "午餐 · 待记录", tags: ["拍照记录"], kcal: nil)
            }
        }
    }

    private func logCard(emoji: String, name: String, tags: [String], kcal: Int?) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title2)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            VStack(alignment: .leading, spacing: 5) {
                Text(name).font(.subheadline.bold())
                HStack(spacing: 5) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag).font(.caption2)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.07)))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let kcal {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(kcal)").font(.headline)
                    Text("kcal").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .cardStyle()
    }
}
