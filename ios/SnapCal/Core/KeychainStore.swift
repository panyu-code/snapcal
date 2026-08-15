import Foundation

/// Token 存取 (开发期用 UserDefaults; 上架前换 Keychain)
enum KeychainStore {

    private static let key = "snapcal-auth-token"

    static var token: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
