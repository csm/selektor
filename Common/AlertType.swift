//
//  AlertType.swift
//  Selektor
//
//  Created by Casey Marshall on 12/9/22.
//

import Foundation
import RealmSwift

enum AlertType: FailableCustomPersistable {
    typealias PersistedType = Data
    
    case none
    case everyTime
    case valueChanged
    case valueIsGreaterThan(value: Decimal, orEquals: Bool = false)
    case valueIsLessThan(value: Decimal, orEquals: Bool = false)
    
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
    
    static func alertType(forTag tag: String?, compareValue: Decimal = 0.0, orEquals: Bool = false) -> AlertType {
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
    
    init?(persistedValue: Data) {
        do {
            let obj = try JSONDecoder().decode([String].self, from: persistedValue)
            if obj.count > 0 {
                let tag = obj[0]
                if tag == "n" {
                    self = .none
                    return
                } else if tag == "e" {
                    self = .everyTime
                    return
                } else if tag == "c" {
                    self = .valueChanged
                    return
                } else if tag == "<" {
                    if obj.count == 3 {
                        if let compareValue = Decimal(string: obj[1]) {
                            self = .valueIsLessThan(value: compareValue, orEquals: obj[2] == "true")
                            return
                        }
                    }
                } else if tag == ">" {
                    if obj.count == 3 {
                        if let compareValue = Decimal(string: obj[1]) {
                            self = .valueIsGreaterThan(value: compareValue, orEquals: obj[2] == "true")
                            return
                        }
                    }
                }
            }
        } catch {
        }
        return nil
    }
    
    var persistableValue: Data {
        get {
            let obj: [String]
            switch self {
            case .none, .everyTime, .valueChanged:
                obj = [self.tag]
            case .valueIsGreaterThan(value: let value, orEquals: let orEquals):
                obj = [self.tag, value.formatted(), "\(orEquals)"]
            case .valueIsLessThan(value: let value, orEquals: let orEquals):
                obj = [self.tag, value.formatted(), "\(orEquals)"]
            }
            return try! JSONEncoder().encode(obj)
        }
    }
}
