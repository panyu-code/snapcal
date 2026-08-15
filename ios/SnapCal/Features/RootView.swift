import SwiftUI

/// 根视图: 启动判断 → 登录页 / 主框架
struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            if !app.booted {
                LaunchPlaceholder()
            } else if app.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.booted)
        .animation(.easeInOut(duration: 0.25), value: app.isLoggedIn)
    }
}

private struct LaunchPlaceholder: View {
    var body: some View {
        ZStack {
            Color.pageBG.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("📸").font(.system(size: 56))
                Text("SnapCal").font(.title2.bold()).foregroundStyle(.brandGreen)
            }
        }
    }
}

/// 五 Tab 主框架 (照原型①④⑤⑥ + 中央拍照入口)
struct MainTabView: View {
    @EnvironmentObject private var app: AppModel
    @State private var tab: Tab = .today

    enum Tab: Hashable { case today, history, trends, profile }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                TodayView()
                    .tabItem { Label("今日", systemImage: "house.fill") }.tag(Tab.today)
                HistoryView()
                    .tabItem { Label("记录", systemImage: "book.fill") }.tag(Tab.history)
                Color.clear
                    .tabItem { Label("", systemImage: "camera.fill") }.tag(Tab.self.cameraDummy)
                TrendsView()
                    .tabItem { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") }.tag(Tab.trends)
                ProfileView()
                    .tabItem { Label("我的", systemImage: "person.fill") }.tag(Tab.profile)
            }
            .tint(.brandGreen)
            .preferredColorScheme(.dark)

            // 中央悬浮拍照按钮 (M2 实现相机)
            HStack {
                Spacer()
                CameraFab { print("M2: 打开相机") }
                    .padding(.trailing, 24)
                    .padding(.bottom, 66)
            }
            .allowsHitTesting(true)
        }
    }
}

private extension Tab {
    static let cameraDummy = Tab.history
}

struct CameraFab: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(hex: 0x04150C))
                .frame(width: 58, height: 58)
                .background(
                    Circle().fill(
                        LinearGradient(colors: [.brandGreen, Color(hex: 0x059669)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                )
                .shadow(color: .brandGreen.opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
