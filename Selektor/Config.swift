//
//  Config.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import Foundation
import SwiftMsgpack

extension Config {
    var selector: Selector? {
        get {
            let decoder = MsgPackDecoder()
            if let config = self.selectorConfig {
                do {
                    return try decoder.decode(Selector.self, from: config)
                } catch {
                    return nil
                }
            }
            return nil
        }
        set {
            let encoder = MsgPackEncoder()
            do {
                self.selectorConfig = try encoder.encode(newValue)
            } catch {
                self.selectorConfig = nil
            }
        }
    }
    
    var result: Result? {
        get {
            let decoder = MsgPackDecoder()
            if let encoded = self.lastValue {
                do {
                    return try decoder.decode(Result.self, from: encoded)
                } catch {
                    return nil
                }
            }
            return nil
        }
        set {
            let encoder = MsgPackEncoder()
            do {
                self.lastValue = try encoder.encode(newValue)
            } catch {
            }
        }
    }
}
