//
//  Config.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import Foundation
import SwiftMsgpack

extension Int64 {
    func positive() -> Int64 {
        if self <= 0 {
            return 1
        } else {
            return self
        }
    }
}

extension Config {
    var result: Result? {
        get {
            let decoder = MsgPackDecoder()
            if let encoded = self.lastValue {
                do {
                    return try decoder.decode(Result.self, from: encoded)
                } catch {
                    logger.error("failed to decode lastResult \(encoded.description): \(error)")
                    return nil
                }
            }
            return nil
        }
        set {
            let encoder = MsgPackEncoder()
            do {
                if let v = newValue {
                    self.lastValue = try encoder.encode(v)
                } else {
                    self.lastValue = nil
                }
            } catch {
                logger.error("failed to encode value \(newValue?.description() ?? "nil"): \(error)")
                self.lastValue = nil
            }
        }
    }
    
    var nextFireDate: Date {
        return max((self.lastFetch ?? Date.distantPast).addingTimeInterval(TimeUnit.forTag(tag: self.triggerIntervalUnits ?? "d").toTimeInterval(timeValue: self.triggerInterval.positive())), Date())
    }
    
    var alertType: AlertType {
        get {
            return AlertType.alertType(forTag: self.alertTypeTag, compareValue: self.alertCompareValue, orEquals: self.alertOrEquals)
        }
        set {
            self.alertTypeTag = newValue.tag
            switch newValue {
            case let .valueIsGreaterThan(value, orEquals):
                self.alertCompareValue = value
                self.alertOrEquals = orEquals
            case let .valueIsLessThan(value, orEquals):
                self.alertCompareValue = value
                self.alertOrEquals = orEquals
            default:
                break
            }
        }
    }
}

extension History {
    var result: Result? {
        get {
            let decoder = MsgPackDecoder()
            if let encoded = self.resultData {
                do {
                    return try decoder.decode(Result.self, from: encoded)
                } catch {
                    logger.error("failed to decode result \(encoded): \(error)")
                }
            }
            return nil
        }
        set {
            let encoder = MsgPackEncoder()
            do {
                if let v = newValue {
                    self.resultData = try encoder.encode(v)
                } else {
                    self.resultData = nil
                }
            } catch {
                logger.error("failed to encode value \(newValue?.description() ?? "nil"): \(error)")
                self.resultData = nil
            }
        }
    }
}
