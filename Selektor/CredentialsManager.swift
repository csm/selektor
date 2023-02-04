//
//  CredentialsManager.swift
//  Selektor
//
//  Created by Casey Marshall on 1/24/23.
//

import Foundation
import Security

#if DEBUG
let SERVER = "dev.selektor.app"
#else
let SERVER = "api.selektor.app"
#endif

enum CredentialsError: Error {
    case SystemError(code: OSStatus)
    case TokenEncodingError
    case InternalError
    case InvalidResponseError
    case ServiceError(httpCode: Int)
}

struct AddUserResponse: Codable {
    let token: String
}

class CredentialsManager {
    static let shared = CredentialsManager()
    
    var credentials: String? {
        get throws {
            let keychainItem: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrAccount as String: SubscriptionManager.shared.appAccountId.uuidString,
                kSecAttrServer as String: SERVER,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecReturnAttributes as String: true,
                kSecReturnData as String: true
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(keychainItem as CFDictionary, &result)
            if status == errSecItemNotFound {
                return nil
            }
            if status != errSecSuccess {
                throw CredentialsError.SystemError(code: status)
            }
            guard let dict = result as? NSDictionary else {
                return nil
            }
            guard let tokenData = dict[kSecValueData] as? Data else {
                return nil
            }
            guard let token = String(data: tokenData, encoding: .utf8) else {
                return nil
            }
            return token
        }
    }
    
    private func set(token: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw CredentialsError.TokenEncodingError
        }
        let status: OSStatus
        if try self.credentials == nil {
            let keychainItem = [
                kSecClass: kSecClassInternetPassword,
                kSecAttrAccount: SubscriptionManager.shared.appAccountId.uuidString,
                kSecAttrServer: SERVER,
                kSecValueData: tokenData,
                kSecReturnRef: true
            ] as CFDictionary
            var result: AnyObject?
            status = SecItemAdd(keychainItem, &result)
        } else {
            let searchItem = [
                kSecClass: kSecClassInternetPassword,
                kSecAttrAccount: SubscriptionManager.shared.appAccountId.uuidString,
                kSecAttrServer: SERVER,
            ] as CFDictionary
            let attibutes = [
                kSecValueData: tokenData
            ] as CFDictionary
            status = SecItemUpdate(searchItem, attibutes)
        }
        if status != errSecSuccess {
            throw CredentialsError.SystemError(code: status)
        }
    }
    
    func exchangeCredentials() async throws {
        if let jws = await SubscriptionManager.shared.currentEntitlementJws() {
            guard let url = URL(string: "https://\(SERVER)/api/add_user") else {
                throw CredentialsError.InternalError
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            let requestMap = ["transaction_jws": jws]
            request.httpBody = try JSONEncoder().encode(requestMap)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw CredentialsError.InvalidResponseError
            }
            switch response.statusCode {
            case 200:
                let result = try JSONDecoder().decode(AddUserResponse.self, from: data)
                try set(token: result.token)
            default: throw CredentialsError.ServiceError(httpCode: response.statusCode)
            }
        }
    }
}
