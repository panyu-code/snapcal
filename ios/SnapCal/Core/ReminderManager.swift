import Foundation
import UserNotifications

/// 用餐提醒: 每天固定时间本地通知 (8:00 早餐 / 12:00 午餐 / 18:00 晚餐)
final class ReminderManager {

    static let shared = ReminderManager()
    private let center = UNUserNotificationCenter.current()

    /// 默认提醒时间 (时, 分)
    static let defaultTimes: [(Int, Int)] = [(8, 0), (12, 0), (18, 0)]
    static let storageKey = "snapcal-reminder-times"
    static let enabledKey = "snapcal-reminder-enabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            Task { await apply(newValue) }
        }
    }

    /// 存储格式 "8:00,12:00,18:00"
    var times: [(Int, Int)] {
        get {
            let raw = UserDefaults.standard.string(forKey: Self.storageKey)
                ?? Self.defaultTimes.map { "\($0.0):\($0.1 == 0 ? "00" : String($0.1))" }
                .joined(separator: ",")
            return raw.split(separator: ",").compactMap { pair in
                let parts = pair.split(separator: ":")
                guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
                      (0...23).contains(h), (0...59).contains(m) else { return nil }
                return (h, m)
            }
        }
        set {
            let raw = newValue.map { "\($0.0):\($0.1 == 0 ? "00" : String($0.1))" }
                .joined(separator: ",")
            UserDefaults.standard.set(raw, forKey: Self.storageKey)
            if isEnabled { Task { await apply(true) } }
        }
    }

    /// 应用设置: 开启则重排通知, 关闭则全部撤销
    func apply(_ enabled: Bool) async {
        if !enabled {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            return
        }
        let granted = await (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        for (hour, minute) in times.prefix(5) {
            let content = UNMutableNotificationContent()
            content.title = "该记一餐啦 📸"
            content.body = "拍下餐盘或手动记录, 今天也吃得明白 ~"
            content.sound = .default
            var date = DateComponents()
            date.hour = hour
            date.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: "meal-\(hour)-\(minute)",
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private var identifiers: [String] {
        ["meal-8-0", "meal-12-0", "meal-18-0"] + times.map { "meal-\($0.0)-\($0.1)" }
    }
}
