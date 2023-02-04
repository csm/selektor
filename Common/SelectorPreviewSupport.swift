//
//  SelectorPreviewSupport.swift
//  Selektor
//
//  Created by Casey Marshall on 1/14/23.
//

import Foundation
import WebKit

struct ElementSelectResult: Codable {
    let selector: String
    let index: Int
}

protocol OnScriptResultHandler {
    var id: String { get }
    func onScriptResult(text: String)
    func isEqual(that: any OnScriptResultHandler) -> Bool
}

class ScriptMessageHandlerImpl: NSObject, WKScriptMessageHandler {
    static let shared = ScriptMessageHandlerImpl()
    var handlers: [OnScriptResultHandler] = []

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logger.debug("received message name: \(message.name) body: \(message.body)")
        if message.name == "clickElement" {
            if let body = message.body as? String {
                handlers.forEach { handler in handler.onScriptResult(text: body) }
            }
        }
    }
    
    func registerHandler(handler: OnScriptResultHandler) {
        handlers.append(handler)
    }
    
    func unregisterHandler(handler: OnScriptResultHandler) {
        handlers = handlers.filter { e in !e.isEqual(that: handler) }
    }
}
