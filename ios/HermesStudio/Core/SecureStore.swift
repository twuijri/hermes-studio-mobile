import Foundation
import Security

enum SecureStore {
    private static let service = "us.i3u.hermesstudio.ios"

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var insert = query; insert[kSecValueData as String] = data; insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    static func get(_ key: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}

enum Preferences {
    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: "baseURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "baseURL") }
    }
    static var profile: String {
        get { UserDefaults.standard.string(forKey: "profile") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "profile") }
    }
    static var language: String {
        get { UserDefaults.standard.string(forKey: "language") ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: "language") }
    }
    static var appearance: String {
        get { UserDefaults.standard.string(forKey: "appearance") ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: "appearance") }
    }
    static var reasoningEffort: String {
        get { UserDefaults.standard.string(forKey: "reasoningEffort") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "reasoningEffort") }
    }
    static func session(for profile: String) -> String { UserDefaults.standard.string(forKey: "session.\(profile)") ?? "" }
    static func setSession(_ id: String, profile: String) { UserDefaults.standard.set(id, forKey: "session.\(profile)") }
}
