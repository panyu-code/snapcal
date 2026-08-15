import SwiftUI

/// 主题模式
enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 主题管理
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("snapcal-theme") private var stored = ThemeMode.system.rawValue

    var mode: ThemeMode {
        get { ThemeMode(rawValue: stored) ?? .system }
        set { stored = newValue.rawValue }
    }

    var colorScheme: ColorScheme? { mode.colorScheme }
}
