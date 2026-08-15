import SwiftUI

/// 全局应用状态: 登录态 + 当前用户
@MainActor
final class AppModel: ObservableObject {

    @AppStorage("devUsername") private var storedDevUsername: String = ""
    @Published var user: User?
    @Published var booted = false

    private let api = APIClient.shared

    var isLoggedIn: Bool { user != nil }

    init() {
        Task { await restoreSession() }
    }

    /// 启动时用本地 token 恢复会话
    func restoreSession() async {
        defer { booted = true }
        guard KeychainStore.token != nil else { return }
        do {
            user = try await api.get(User.self, path: "/user/me")
        } catch {
            KeychainStore.token = nil
        }
    }

    /// 开发模式登录 (模拟器调试)
    func devLogin(username: String) async throws {
        struct LoginResp: Codable { let token: String; let user: User }
        let resp: LoginResp = try await api.post(path: "/auth/dev-login", body: ["username": username])
        KeychainStore.token = resp.token
        user = resp.user
        storedDevUsername = username
    }

    /// Apple 登录
    func appleLogin(identityToken: String, nickname: String?) async throws {
        struct LoginResp: Codable { let token: String; let user: User }
        var body: [String: String] = ["identityToken": identityToken]
        if let nickname { body["nickname"] = nickname }
        let resp: LoginResp = try await api.post(path: "/auth/apple", body: body)
        KeychainStore.token = resp.token
        user = resp.user
    }

    func logout() {
        KeychainStore.token = nil
        user = nil
    }

    func refreshMe() async {
        if let u = try? await api.get(User.self, path: "/user/me") {
            user = u
        }
    }
}
