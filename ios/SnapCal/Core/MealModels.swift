import Foundation

// MARK: - 识别结果 (对应后端 RecognizeResultVO)

struct RecognizeResult: Codable {
    let image: String?
    let items: [FoodItem]
    let engine: String?

    struct FoodItem: Codable, Identifiable {
        let id = UUID()
        var name: String
        var weightG: Int
        var kcal: Int
        var proteinG: Double?
        var carbsG: Double?
        var fatG: Double?
        var confidence: Double?

        enum CodingKeys: String, CodingKey {
            case name, weightG, kcal, proteinG, carbsG, fatG, confidence
        }
    }
}

// MARK: - 餐次 (对应后端 MealVO)

struct Meal: Codable, Identifiable {
    let id: Int64?
    var mealType: String
    var photoUrl: String?
    var totalKcal: Int?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var eatTime: String?
    var items: [MealItem]?

    struct MealItem: Codable, Identifiable {
        let id = UUID()
        let foodName: String
        let weightG: Int
        var kcal: Int?
        var proteinG: Double?
        var carbsG: Double?
        var fatG: Double?
        var source: String?

        enum CodingKeys: String, CodingKey {
            case foodName, weightG, kcal, proteinG, carbsG, fatG, source
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, mealType, photoUrl, totalKcal, proteinG, carbsG, fatG, eatTime, items
    }

    var mealTypeName: String {
        switch mealType {
        case "BREAKFAST": return "早餐"
        case "LUNCH": return "午餐"
        case "DINNER": return "晚餐"
        default: return "加餐"
        }
    }
}

struct MealSaveReq: Codable {
    var mealType: String
    var photoUrl: String?
    var eatTime: String?
    var items: [MealSaveItem]

    struct MealSaveItem: Codable {
        let foodName: String
        let weightG: Int
        var kcal: Int?
        var proteinG: Double?
        var carbsG: Double?
        var fatG: Double?
        var source: String?
    }
}

// MARK: - 食物库 (对应后端 Food)

struct Food: Codable, Identifiable {
    let id: Int64
    let name: String
    var emoji: String?
    let category: String?
    var kcalPer100g: Int?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
}

extension Notification.Name {
    /// 餐次保存成功, 今日页收到后刷新
    static let mealSaved = Notification.Name("SnapCalMealSaved")
}

/// 空 payload (DELETE 等接口 data 为 null)
struct EmptyPayload: Codable {}
