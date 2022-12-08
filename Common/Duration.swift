//
//  Duration.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import Foundation

enum DurationError: Error {
    case InvalidDurationError
}

enum TimeUnit {
    case Seconds
    case Minutes
    case Hours
    case Days
    
    func tag() -> String {
        switch self {
        case .Seconds: return "s"
        case .Minutes: return "m"
        case .Hours: return "h"
        case .Days: return "d"
        }
    }
    
    static func forTag(tag: String) -> TimeUnit {
        if tag == "m" {
            return .Minutes
        } else if tag == "h" {
            return .Hours
        } else if tag == "d" {
            return .Days
        } else {
            return .Seconds
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
