//
//  NavigationDelegateImpl.swift
//  Selektor
//
//  Created by Casey Marshall on 1/3/23.
//

import Foundation
import WebKit

class NavigationDelegateImpl: NSObject, WKNavigationDelegate {
    static var shared = NavigationDelegateImpl()
    var blocks: [any OnCommitHandler] = []
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        blocks.forEach { handler in
            handler.onCommit(webView: webView)
        }
    }
    
    func registerListener(listener: any OnCommitHandler) {
        blocks.append(listener)
    }
    
    func unregisterListener(listener: any OnCommitHandler) {
        blocks = blocks.filter { e in !e.isEqual(that: listener) }
    }
}

protocol OnCommitHandler {
    var id: String { get }
    func onCommit(webView: WKWebView) -> Void
    func isEqual(that: any OnCommitHandler) -> Bool
}
