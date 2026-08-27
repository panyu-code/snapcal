import Foundation

// MARK: - 后端统一响应

struct ApiResult<T: Codable>: Codable {
    let code: Int
    let message: String?
    let data: T?
}

// MARK: - 用户模型 (对应后端 UserVO)

struct User: Codable, Identifiable {
    let id: Int64
    var nickname: String?
    var avatar: String?
    var gender: Int?            // 1男 2女
    var birthYear: Int?
    var heightCm: Double?
    var targetType: String?     // LOSE/KEEP/GAIN
    var goalWeightKg: Double?
    var dailyKcalTarget: Int?
    var currentWeightKg: Double?
    var isPro: Bool?

    var targetTypeName: String {
        switch targetType {
        case "GAIN": return "增肌"
        case "KEEP": return "维持"
        default: return "减脂"
        }
    }
}

// MARK: - 资料更新请求

struct ProfileUpdateReq: Codable {
    var nickname: String?
    var gender: Int?
    var birthYear: Int?
    var heightCm: Double?
    var currentWeightKg: Double?
    var goalWeightKg: Double?
    var targetType: String?
    var pace: String?
    var activityFactor: Double?
}

// MARK: - 饮水

struct WaterToday: Codable {
    let date: String
    var totalMl: Int
    let goalMl: Int
}
