//
//  Selector.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import Foundation
import SwiftMsgpackCsm

extension Config {
    func getLastValue() -> Result? {
        if let d = self.lastValue {
            let decoder = MsgPackDecoder()
            do {
                return try decoder.decode(Result.self, from: d)
            } catch {
                logger.error("could not decode lastValue: \(error)")
            }
        }
        return nil
    }
}
