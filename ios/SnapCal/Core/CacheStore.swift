import Foundation
import SwiftData

/// 离线缓存条目 (餐次/统计 JSON)
@Model
final class CachedPayload {
    /// 缓存键 (如 meals-2026-08-16 / stats-7d)
    @Attribute(.unique) var key: String
    var json: String
    var updatedAt: Date

    init(key: String, json: String, updatedAt: Date = .now) {
        self.key = key
        self.json = json
        self.updatedAt = updatedAt
    }
}

/// 离线缓存管理: 网络失败时读缓存, 成功时写缓存
@MainActor
final class CacheStore {

    static let shared = CacheStore()

    private var context: ModelContext?
    private(set) var ready = false

    func setup(container: ModelContainer) {
        context = ModelContext(container)
        ready = true
    }

    func save<T: Encodable>(key: String, value: T) {
        guard let context, let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else { return }
        let fetch = FetchDescriptor<CachedPayload>(predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(fetch).first {
            existing.json = json
            existing.updatedAt = .now
        } else {
            context.insert(CachedPayload(key: key, json: json))
        }
        try? context.save()
    }

    func remove(key: String) {
        guard let context else { return }
        let fetch = FetchDescriptor<CachedPayload>(predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(fetch).first {
            context.delete(existing)
            try? context.save()
        }
    }

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let context else { return nil }
        let fetch = FetchDescriptor<CachedPayload>(predicate: #Predicate { $0.key == key })
        guard let entry = try? context.fetch(fetch).first,
              let data = entry.json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
