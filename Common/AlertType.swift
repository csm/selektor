//
//  AlertType.swift
//  Selektor
//
//  Created by Casey Marshall on 12/9/22.
//

import Foundation

enum AlertType {
    case none
    case everyTime
    case valueChanged
    case valueIsGreaterThan(value: Float, orEquals: Bool = false)
    case valueIsLessThan(value: Float, orEquals: Bool = false)
    
    var tag: String {
        get {
            switch self {
            case .none: return "n"
            case .everyTime: return "e"
            case .valueChanged: return "c"
            case .valueIsGreaterThan: return ">"
            case .valueIsLessThan: return "<"
            }
        }
    }
    
    static func alertType(forTag tag: String?, compareValue: Float, orEquals: Bool) -> AlertType {
        if tag == "<" {
            return AlertType.valueIsLessThan(value: compareValue, orEquals: orEquals)
        } else if tag == ">" {
            return AlertType.valueIsGreaterThan(value: compareValue, orEquals: orEquals)
        } else if tag == "e" {
            return AlertType.everyTime
        } else if tag == "c" {
            return AlertType.valueChanged
        } else {
            return AlertType.none
        }
    }
}
