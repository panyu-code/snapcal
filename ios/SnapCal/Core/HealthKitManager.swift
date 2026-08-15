import Foundation
import HealthKit

/// HealthKit 桥接: 读步数/活动消耗, 写膳食能量
final class HealthKitManager {

    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private(set) var available = HKHealthStore.isHealthDataAvailable()

    /// 请求权限 (步数/活动能量 读; 膳食能量 写)
    func requestAuthorization() async {
        guard available else { return }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!
        ]
        try? await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    /// 今日步数
    func todayStepCount() async -> Int {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return await sum(type, unit: HKUnit.count()) as? Int ?? 0
    }

    /// 今日活动消耗 (kcal)
    func todayActiveEnergy() async -> Int {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await sum(type, unit: HKUnit.kilocalorie()) as? Int ?? 0
    }

    /// 写入一餐膳食能量 (kcal)
    func writeMeal(kcal: Int, proteinG: Double, carbsG: Double, fatG: Double, at date: Date) async {
        guard available else { return }
        let values: [(HKQuantityTypeIdentifier, HKUnit, Double)] = [
            (.dietaryEnergyConsumed, .kilocalorie(), Double(kcal)),
            (.dietaryProtein, .gram(), proteinG),
            (.dietaryCarbohydrates, .gram(), carbsG),
            (.dietaryFatTotal, .gram(), fatG)
        ]
        for (identifier, unit, value) in values {
            guard value > 0, let type = HKObjectType.quantityType(forIdentifier: identifier) else { continue }
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
            try? await store.save(sample)
        }
    }

    // MARK: - 私有

    private func sum(_ type: HKQuantityType, unit: HKUnit) async -> Double {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
