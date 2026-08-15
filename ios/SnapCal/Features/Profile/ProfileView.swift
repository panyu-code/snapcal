import SwiftUI

/// 我的页: 个人资料 + 目标进度 + 设置 (照原型⑥)
struct ProfileView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showEdit = false
    @State private var showLogout = false

    private var user: User? { app.user }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    goalCard
                    settingsCard
                }
                .padding(.horizontal, 18)
            }
            .background(Color.pageBG)
            .navigationTitle("我的")
            .sheet(isPresented: $showEdit) {
                ProfileEditView()
                    .environmentObject(app)
            }
            .confirmationDialog("退出登录?", isPresented: $showLogout, titleVisibility: .visible) {
                Button("退出", role: .destructive) { app.logout() }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [.brandGreen, .brandBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Text("🐟").font(.system(size: 30))
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(user?.nickname ?? "未命名").font(.title3.bold())
                Text("SnapCal 陪你吃得明白 · 目标 \(user?.dailyKcalTarget ?? 2200) kcal/天")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .cardStyle()
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎯 \(user?.targetTypeName ?? "减脂")目标").font(.subheadline.bold())
                Spacer()
                Button("编辑") { showEdit = true }
                    .font(.caption).foregroundStyle(.brandGreen)
            }

            HStack {
                goalNum(value: user?.currentWeightKg.map { String(format: "%.1f", $0) } ?? "—", label: "当前 kg")
                goalNum(value: String(format: "%.1f", user?.goalWeightKg ?? 60), label: "目标 kg")
                goalNum(value: "\(user?.dailyKcalTarget ?? 2200)", label: "每日 kcal", color: .brandOrange)
            }

            if let current = user?.currentWeightKg,
               let goal = user?.goalWeightKg, current > goal {
                let start = current   // M4: 记录起始体重后改为真实起始值
                let progress = min(max((start - current) / max(start - goal, 0.01), 0), 1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(
                            LinearGradient(colors: [.brandBlue, .brandGreen], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 8)
                Text("已完成 \(Int(progress * 100))%")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("完善资料与体重后显示进度")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.12, green: 0.23, blue: 0.37)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0x2B4A73)))
    }

    private func goalNum(value: String, label: String, color: Color = .brandGreen) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            cell(icon: "👤", title: "个人资料", value: profileSummary) { showEdit = true }
            Divider().overlay(Color.white.opacity(0.06))
            cell(icon: "❤️", title: "健康数据 (Apple 健康)", value: "M4") {}
            Divider().overlay(Color.white.opacity(0.06))
            cell(icon: "💎", title: "SnapCal Pro", value: "M5") {}
            Divider().overlay(Color.white.opacity(0.06))
            cell(icon: "🚪", title: "退出登录", value: "", destructive: true) { showLogout = true }
        }
        .padding(.vertical, 4)
        .cardStyle()
    }

    private var profileSummary: String {
        guard let u = user, u.birthYear != nil else { return "待完善" }
        return "\(u.heightCm.map { Int($0) } ?? 0)cm · \(u.birthYear ?? 0)年"
    }

    private func cell(icon: String, title: String, value: String,
                      destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon).font(.title3)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(destructive ? Color.brandRed : Color.primary)
                Spacer()
                Text(value).font(.caption).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
