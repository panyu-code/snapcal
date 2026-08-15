import Foundation

enum APIError: LocalizedError {
    case http(Int, String?)
    case decoding(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .http(401, _): return "登录已过期，请重新登录"
        case .http(let code, let msg): return msg ?? "请求失败 (\(code))"
        case .decoding(let msg): return "数据解析失败: \(msg)"
        case .network(let err): return "网络异常: \(err.localizedDescription)"
        }
    }
}

/// 极简 API 客户端: JSON + Bearer Token
final class APIClient {

    static let shared = APIClient()

    /// 开发服务器 (上架前替换为 HTTPS 域名)
    #if DEBUG
    static let baseURL = URL(string: "http://myblog.wiki:8081/api")!
    #else
    static let baseURL = URL(string: "https://api.myblog.wiki/api")!
    #endif

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    // MARK: - 请求方法

    func get<T: Codable>(_ type: T.Type, path: String) async throws -> T {
        try await request(path: path, method: "GET")
    }

    func post<T: Codable>(path: String, body: [String: String]) async throws -> T {
        try await request(path: path, method: "POST", body: encode(body))
    }

    func post<T: Codable>(path: String, body: some Encodable) async throws -> T {
        try await request(path: path, method: "POST", body: encode(body))
    }

    func put<T: Codable>(path: String, body: some Encodable) async throws -> T {
        try await request(path: path, method: "PUT", body: encode(body))
    }

    /// multipart 上传 (图片识别)
    func upload<T: Codable>(_ type: T.Type, path: String, imageData: Data, fieldName: String = "file",
                            fileName: String = "meal.jpg") async throws -> T {
        let boundary = "SnapCalBoundary\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = KeychainStore.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let result = try? JSONDecoder().decode(ApiResult<T>.self, from: data) else {
            throw APIError.decoding("上传响应解析失败")
        }
        guard result.code == 200, let payload = result.data else {
            throw APIError.http(result.code, result.message)
        }
        return payload
    }

    // MARK: - 核心

    private func request<T: Codable>(path: String, method: String, body: Data? = nil) async throws -> T {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainStore.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        guard let result = try? JSONDecoder().decode(ApiResult<T>.self, from: data) else {
            throw APIError.decoding(String(data: data.prefix(200), encoding: .utf8) ?? "未知响应")
        }
        guard result.code == 200, let payload = result.data else {
            throw APIError.http(result.code, result.message)
        }
        return payload
    }

    private func encode(_ body: some Encodable) -> Data? {
        try? JSONEncoder().encode(body)
    }
}
