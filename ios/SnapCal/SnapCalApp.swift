import SwiftUI
import SwiftData

@main
struct SnapCalApp: App {
    @StateObject private var app = AppModel()
    @StateObject private var theme = ThemeManager.shared
    private let modelContainer: ModelContainer

    init() {
        // SwiftData 初始化: 磁盘失败退内存模式 (防御真机闪退)
        if let container = try? ModelContainer(for: CachedPayload.self) {
            modelContainer = container
        } else {
            let memConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = (try? ModelContainer(for: CachedPayload.self, configurations: memConfig))
                ?? (try! ModelContainer())
        }
        CacheStore.shared.setup(container: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(theme)
                .tint(.brandGreen)
                .preferredColorScheme(theme.colorScheme)
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - 主题色

extension Color {
    static let brandGreen = Color(red: 0.20, green: 0.83, blue: 0.60)   // #34D399
    static let brandBlue = Color(red: 0.38, green: 0.65, blue: 0.98)    // #60A5FA
    static let brandOrange = Color(red: 0.98, green: 0.57, blue: 0.24)  // #FB923C
    static let brandRed = Color(red: 0.97, green: 0.43, blue: 0.43)     // #F87171

    /// 页面背景 (深色 #161B26 / 浅色 #F2F4F8)
    static var pageBG: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.086, green: 0.106, blue: 0.149, alpha: 1)
                : UIColor(red: 0.949, green: 0.957, blue: 0.973, alpha: 1)
        })
    }

    /// 卡片背景 (深色 #1D2433 / 浅色 白色)
    static var cardBG: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.114, green: 0.141, blue: 0.20, alpha: 1)
                : UIColor(white: 1, alpha: 1)
        })
    }

    /// 分隔线/描边 (自适应)
    static var dividerLine: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.08)
                : UIColor(white: 0, alpha: 0.08)
        })
    }

    /// 目标虚线 (自适应)
    static var targetLine: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.35)
                : UIColor(white: 0, alpha: 0.30)
        })
    }

    /// 弱背景填充 (自适应)
    static var weakFill: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.06)
                : UIColor(white: 0, alpha: 0.05)
        })
    }
}

extension ShapeStyle where Self == Color {
    static var brandGreen: Color { .brandGreen }
    static var brandBlue: Color { .brandBlue }
    static var brandOrange: Color { .brandOrange }
    static var brandRed: Color { .brandRed }
    static var pageBG: Color { .pageBG }
    static var cardBG: Color { .cardBG }
    static var dividerLine: Color { .dividerLine }
    static var weakFill: Color { .weakFill }
    static var targetLine: Color { .targetLine }
}
