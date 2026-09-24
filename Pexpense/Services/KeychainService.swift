//
//  KeychainService.swift
//  Pexpense
//

import Foundation
import Security

/// Protocol defining secure token storage operations.
protocol TokenStore: AnyObject, Sendable {
    func loadAccessToken() -> String?
    func loadRefreshToken() -> String?
    func save(accessToken: String, refreshToken: String) throws
    func clear()
}

/// Keychain-backed implementation of TokenStore.
///
/// Uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` as required by AGENTS.md §6.
/// Note: Items survive app uninstallation on iOS; a fresh launch detection can be used if needed.
final class KeychainService: TokenStore, @unchecked Sendable {
    static let shared = KeychainService()

    private let service: String
    private let accessGroup: String?

    private enum Key {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
    }

    init(service: String = "ch.pexpense.app.tokens", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    func loadAccessToken() -> String? {
        readString(forKey: Key.accessToken)
    }

    func loadRefreshToken() -> String? {
        readString(forKey: Key.refreshToken)
    }

    func save(accessToken: String, refreshToken: String) throws {
        try writeString(accessToken, forKey: Key.accessToken)
        try writeString(refreshToken, forKey: Key.refreshToken)
    }

    func clear() {
        delete(forKey: Key.accessToken)
        delete(forKey: Key.refreshToken)
    }

    // MARK: - Private Keychain Helpers

    private func writeString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first to ensure clean state
        delete(forKey: key)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func readString(forKey key: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func delete(forKey key: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error, LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            return "Keychain operation failed with status code \(status)."
        }
    }
}
