import SwiftUI

@main
struct SnapCalApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(.brandGreen)
        }
    }
}

// MARK: - 主题色

extension Color {
    static let brandGreen = Color(red: 0.20, green: 0.83, blue: 0.60)   // #34D399
    static let brandBlue = Color(red: 0.38, green: 0.65, blue: 0.98)    // #60A5FA
    static let brandOrange = Color(red: 0.98, green: 0.57, blue: 0.24)  // #FB923C
    static let brandRed = Color(red: 0.97, green: 0.43, blue: 0.43)     // #F87171
    static let pageBG = Color(red: 0.086, green: 0.106, blue: 0.149)    // #161B26
    static let cardBG = Color(red: 0.114, green: 0.141, blue: 0.20)     // #1D2433
}

extension ShapeStyle where Self == Color {
    static var brandGreen: Color { .brandGreen }
    static var brandBlue: Color { .brandBlue }
    static var brandOrange: Color { .brandOrange }
    static var brandRed: Color { .brandRed }
}
