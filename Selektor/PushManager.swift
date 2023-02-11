//
//  PushManager.swift
//  Selektor
//
//  Created by Casey Marshall on 2/2/23.
//

import Foundation
import UserNotifications
import RealmSwift

enum PushError: Error {
    case InternalError
    case InvalidResponseError
    case ServiceError(httpStatus: Int)
}

extension Data {
    func hexString() -> String {
        var result: String = ""
        for byte in self {
            result = result.appendingFormat("%02x", byte)
        }
        return result
    }
}

struct ScheduleEntry: Codable {
    let last_fire: Int64
    let fire_interval: Int64
}

struct UpdateSchedRequest: Codable {
    let entries: [ScheduleEntry]
}

class PushManager {
    static let shared = PushManager()
    
    func registerPushToken(token: Data) async throws {
        if let creds = try CredentialsManager.shared.credentials {
            let tokenStr = token.hexString()
            let requestMap = ["push_token": tokenStr]
            guard let url = URL(string: "https://\(SERVER)/api/register_push") else {
                throw PushError.InternalError
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.setValue("Bearer \(creds)", forHTTPHeaderField: "authorization")
            let bodyData = try JSONEncoder().encode(requestMap)
            let (_, response) = try await URLSession.shared.upload(for: request, from: bodyData)
            guard let response = response as? HTTPURLResponse else {
                throw PushError.InvalidResponseError
            }
            switch response.statusCode {
            case 204: break
            default: throw PushError.ServiceError(httpStatus: response.statusCode)
            }
        }
    }
    
    func updateSchedules() async throws {
        if let creds = try CredentialsManager.shared.credentials {
            let realm = try PersistenceV2.shared.realm
            let results = realm.objects(ConfigV2.self)
            let schedules = Array(results.map { config in
                let fireInterval = config.triggerInterval.toDuration()
                let fireIntervalSeconds = fireInterval.components.seconds
                let lastFetchSeconds: Int64
                if let s = config.lastFetch?.timeIntervalSince1970 {
                    lastFetchSeconds = Int64(s)
                } else {
                    lastFetchSeconds = fireIntervalSeconds
                }
                return ScheduleEntry(last_fire: lastFetchSeconds / 300, fire_interval: fireIntervalSeconds / 300)
            })
            let requestObj = UpdateSchedRequest(entries: schedules)
            if let url = URL(string: "https://\(SERVER)/api/update_sched") {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "content-type")
                request.setValue("Bearer \(creds)", forHTTPHeaderField: "authorization")
                let httpBody = try JSONEncoder().encode(requestObj)
                let (_, response) = try await URLSession.shared.upload(for: request, from: httpBody)
                guard let response = response as? HTTPURLResponse else {
                    throw PushError.InternalError
                }
                switch response.statusCode {
                case 204: break
                default: throw PushError.ServiceError(httpStatus: response.statusCode)
                }
            }
        }
    }
}
