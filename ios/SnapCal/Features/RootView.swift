import SwiftUI

/// 根视图: 启动判断 → 登录页 / 主框架
struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage("snapcal-onboarded") private var onboarded = false

    var body: some View {
        ZStack {
            if !app.booted {
                LaunchPlaceholder()
            } else if !onboarded {
                OnboardingView()
            } else if app.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.booted)
        .animation(.easeInOut(duration: 0.25), value: app.isLoggedIn)
        .animation(.easeInOut(duration: 0.25), value: onboarded)
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
    @State private var tab = 0   // 0今日 1记录 2趋势 3我的
    @State private var showRecognize = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                TodayView()
                    .tabItem { Label("今日", systemImage: "house.fill") }.tag(0)
                HistoryView()
                    .tabItem { Label("记录", systemImage: "book.fill") }.tag(1)
                TrendsView()
                    .tabItem { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") }.tag(2)
                ProfileView()
                    .tabItem { Label("我的", systemImage: "person.fill") }.tag(3)
            }
            .tint(.brandGreen)
            

            // 中央悬浮拍照按钮 → 识别流程
            HStack {
                Spacer()
                CameraFab { showRecognize = true }
                    .padding(.trailing, 24)
                    .padding(.bottom, 66)
            }
        }
        .sheet(isPresented: $showRecognize) {
            RecognizeFlowView().environmentObject(app)
        }
    }
}

struct CameraFab: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.brandGreen)
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
