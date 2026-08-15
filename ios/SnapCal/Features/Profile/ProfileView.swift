import SwiftUI
import PhotosUI

/// 我的页: 个人资料 + 目标进度 + 设置 (照原型⑥)
struct ProfileView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var theme: ThemeManager
    @State private var showEdit = false
    @State private var showLogout = false
    @State private var showThemePicker = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarUploading = false
    @State private var avatarDraft: AvatarDraft?
    @State private var showFoodLibrary = false

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
            .onChange(of: avatarPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        avatarDraft = AvatarDraft(image: image)
                    }
                }
            }
            .sheet(isPresented: $showFoodLibrary) {
                FoodLibraryView()
            }
            .sheet(item: $avatarDraft) { draft in
                AvatarEditorView(image: draft.image) { cropped in
                    Task { await uploadAvatarImage(cropped) }
                }
            }
            .confirmationDialog("选择外观", isPresented: $showThemePicker, titleVisibility: .visible) {
                ForEach(ThemeMode.allCases) { m in
                    Button(m.label) { theme.mode = m }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: [.brandGreen, .brandBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    if let avatar = user?.avatar, let url = URL(string: avatar) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Text("🐟").font(.system(size: 30))
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    } else {
                        Text("🐟").font(.system(size: 30))
                    }
                    // 编辑角标
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.black.opacity(0.55)))
                        }
                    }
                    .frame(width: 64, height: 64)
                    if avatarUploading {
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: 64, height: 64)
            }

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
                        Capsule().fill(.dividerLine)
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardBG))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.dividerLine))
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
            Divider().overlay(.weakFill)
            cell(icon: "🎨", title: "外观", value: theme.mode.label) { showThemePicker = true }
            Divider().overlay(Color.dividerLine)
            cell(icon: "❤️", title: "健康数据 (Apple 健康)", value: "M4") {}
            Divider().overlay(.weakFill)
            cell(icon: "💎", title: "SnapCal Pro", value: "M5") {}
            Divider().overlay(.weakFill)
            cell(icon: "🚪", title: "退出登录", value: "", destructive: true) { showLogout = true }
        }
        .padding(.vertical, 4)
        .cardStyle()
    }

    private func uploadAvatarImage(_ image: UIImage) async {
        avatarUploading = true
        defer { avatarUploading = false }
        guard let jpg = image.jpegData(compressionQuality: 0.75) else { return }
        do {
            let updated: User = try await APIClient.shared.upload(User.self, path: "/user/avatar", imageData: jpg)
            app.user = updated
        } catch {
            // 静默
        }
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
                    .background(RoundedRectangle(cornerRadius: 10).fill(.weakFill))
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

/// 头像草稿 (sheet(item:) 需要 Identifiable)
struct AvatarDraft: Identifiable {
    let id = UUID()
    let image: UIImage
}
