import Foundation
import Security

public enum KeychainCredentialError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

public final class KeychainCredentialStore: GWCredentialProviding, @unchecked Sendable {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(service: String = "MacWorkTimer.GW", account: String = "gw.example.com") {
        self.service = service
        self.account = account
    }

    public func loadCredentials() throws -> GWCredentials? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainCredentialError.unexpectedStatus(status)
        }

        guard let data = item as? Data else {
            return nil
        }

        return try decoder.decode(GWCredentials.self, from: data)
    }

    public func saveCredentials(_ credentials: GWCredentials) throws {
        try deleteCredentials(ignoringMissing: true)

        var query = baseQuery()
        query[kSecValueData as String] = try encoder.encode(credentials)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainCredentialError.unexpectedStatus(status)
        }
    }

    public func deleteCredentials() throws {
        try deleteCredentials(ignoringMissing: false)
    }

    private func deleteCredentials(ignoringMissing: Bool) throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status == errSecItemNotFound && ignoringMissing {
            return
        }
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainCredentialError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
