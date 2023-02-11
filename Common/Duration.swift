//
//  Duration.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import Foundation
import RealmSwift

enum DurationError: Error {
    case InvalidDurationError
}

enum TimeUnit: String, PersistableEnum {
    case Seconds = "s"
    case Minutes = "m"
    case Hours = "h"
    case Days
    
    func tag() -> String {
        switch self {
        case .Seconds: return "s"
        case .Minutes: return "m"
        case .Hours: return "h"
        case .Days: return "d"
        }
    }
    
    static func forTag(tag: String?) -> TimeUnit {
        if tag == "s" {
            return .Seconds
        } else if tag == "h" {
            return .Hours
        } else if tag == "d" {
            return .Days
        } else {
            return .Minutes
        }
    }
    
    func toDuration(timeValue: Int64) -> Duration {
        return .seconds(toTimeInterval(timeValue: timeValue))
    }
    
    func toTimeInterval(timeValue: Int64) -> TimeInterval {
        switch self {
        case .Seconds: return Double(timeValue)
        case .Minutes: return Double(timeValue * 60)
        case .Hours: return Double(timeValue * 60 * 60)
        case .Days: return Double(timeValue * 24 * 60 * 60)
        }
    }
}

extension Duration {
    static func minutes<T>(_ minutes: T) -> Duration where T: BinaryInteger {
        return Duration.seconds(minutes * 60)
    }
    
    static func hours<T>(_ hours: T) -> Duration where T: BinaryInteger {
        return Duration.minutes(hours * 60)
    }
    
    static func days<T>(_ days: T) -> Duration where T: BinaryInteger {
        return Duration.hours(days * 24)
    }
}

struct TimeDuration: FailableCustomPersistable {
    typealias PersistedType = Data
    
    let value: UInt
    let units: TimeUnit
    
    init(value: UInt, units: TimeUnit) {
        self.value = value
        self.units = units
    }
    
    init?(persistedValue: Data) {
        if let result = try? JSONDecoder().decode([String].self, from: persistedValue), result.count == 2 {
            if let v = UInt(result[0]), let u = TimeUnit(rawValue: result[1]) {
                self.value = v
                self.units = u
                return
            }
        }
        return nil
    }
    
    var persistableValue: Data {
        get {
            let obj = ["\(value)", units.rawValue]
            return try! JSONEncoder().encode(obj)
        }
    }
    
    func toDuration() -> Duration {
        switch units {
        case .Seconds: return Duration.seconds(value)
        case .Minutes: return Duration.minutes(value)
        case .Hours: return Duration.hours(value)
        case .Days: return Duration.days(value)
        }
    }
    
    func toTimeInterval() -> TimeInterval {
        return TimeInterval(toDuration().components.seconds)
    }
}
