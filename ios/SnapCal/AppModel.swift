import SwiftUI

/// 全局应用状态: 登录态 + 当前用户
@MainActor
final class AppModel: ObservableObject {

    @AppStorage("devUsername") private var storedDevUsername: String = ""
    @Published var user: User?
    @Published var booted = false

    private let api = APIClient.shared
    private var restoreTask: Task<Void, Never>?

    var isLoggedIn: Bool { user != nil }

    init() {
        restoreTask = Task { await restoreSession() }
    }

    /// 启动时用本地 token 恢复会话 (网络错误不清 token, 仅明确 401 才清)
    func restoreSession() async {
        defer { booted = true }
        guard KeychainStore.token != nil else { return }
        do {
            user = try await api.get(User.self, path: "/user/me")
        } catch let error as APIError {
            if case .http(401, _) = error {
                KeychainStore.token = nil
            }
            // 其他错误 (超时/网络) 保留 token, 用户下次操作会重试
        } catch {
            // 同上
        }
    }

    /// 开发模式登录 (模拟器调试)
    func devLogin(username: String) async throws {
        struct LoginResp: Codable { let token: String; let user: User }
        restoreTask?.cancel()   // 取消可能还在跑的恢复任务, 防止清掉新 token
        let resp: LoginResp = try await api.post(path: "/auth/dev-login", body: ["username": username])
        KeychainStore.token = resp.token
        user = resp.user
        storedDevUsername = username
    }

    /// Apple 登录
    func appleLogin(identityToken: String, nickname: String?) async throws {
        struct LoginResp: Codable { let token: String; let user: User }
        restoreTask?.cancel()
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
