//
//  ErikValueSelector.swift
//  SelektorMac
//
//  Created by Casey Marshall on 2/9/23.
//

import Foundation
import Erik

class ErikValueSelector {
    static func applySelector(url: URL, selector: String, elementIndex: Int, resultType: ResultType) async throws -> Result? {
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.main.async {
                Erik.visit(url: url) { (doc: Document?, error: Error?) in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        if let elements = doc?.querySelectorAll(selector), let text = elements[elementIndex].innerHTML {
                            do {
                                let result = try ValueSelector.decodeResult(text: text, resultType: resultType)
                                cont.resume(returning: result)
                            } catch {
                                cont.resume(throwing: error)
                            }
                        }
                    }
                }
            }
        }
    }
}
