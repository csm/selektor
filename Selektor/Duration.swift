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
    
    func tag() -> String {
        switch self {
        case .Seconds: return "s"
        case .Minutes: return "m"
        case .Hours: return "h"
        }
    }
    
    static func forTag(tag: String) -> TimeUnit {
        if tag == "m" {
            return .Minutes
        } else if tag == "h" {
            return .Hours
        } else {
            return .Seconds
        }
    }
    
    func toDuration(timeValue: Int64) -> Duration {
        switch self {
        case .Seconds: return .seconds(timeValue)
        case .Minutes: return .seconds(timeValue * 60)
        case .Hours: return .seconds(timeValue * 60 * 60)
        }
    }
}
