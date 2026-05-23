//
//  VaultPINStore.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import CryptoKit
import Foundation
import Security

enum VaultPINStore {
    private static let service = "com.gill.Vaulty.pin"
    private static let account = "vault-pin"
    private static let saltLength = 16

    static var hasPIN: Bool {
        loadPINRecord() != nil
    }

    static func setPIN(_ pin: String) throws {
        let salt = try randomData(length: saltLength)
        let hash = hash(pin: pin, salt: salt)
        let record = salt + hash

        var query = baseQuery()
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = record
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    static func verify(_ pin: String) -> Bool {
        guard let record = loadPINRecord(), record.count > saltLength else {
            return false
        }

        let salt = record.prefix(saltLength)
        let storedHash = record.dropFirst(saltLength)
        return hash(pin: pin, salt: Data(salt)) == Data(storedHash)
    }

    private static func loadPINRecord() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func randomData(length: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)

        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }

        return Data(bytes)
    }

    private static func hash(pin: String, salt: Data) -> Data {
        var data = Data()
        data.append(salt)
        data.append(Data(pin.utf8))

        let digest = SHA256.hash(data: data)
        return Data(digest)
    }
}

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            return "Keychain error \(status)."
        }
    }
}
