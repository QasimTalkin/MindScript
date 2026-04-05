import Foundation
import Security

/// Stores and retrieves the Supabase JWT from the system Keychain.
enum SessionStore {
    private static let service = "com.mindscript.app"
    private static let account = "supabase_access_token"
    private static let userIdAccount = "supabase_user_id"

    static var accessToken: String? {
        get { load(account: account) }
        set { newValue == nil ? delete(account: account) : save(newValue!, account: account) }
    }

    static var userId: String? {
        get { load(account: userIdAccount) }
        set { newValue == nil ? delete(account: userIdAccount) : save(newValue!, account: userIdAccount) }
    }

    // MARK: - Keychain helpers

    private static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attrs = query
        attrs[kSecValueData] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private static func load(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
