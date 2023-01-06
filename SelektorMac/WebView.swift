//
//  WebView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/2/23.
//

import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    typealias NSViewType = WKWebView
    
    let webView: WKWebView
    var url: URL? {
        get {
            webView.url
        }
    }
    
    func setUrl(url: URL?) {
        if let u = url {
            DispatchQueue.main.async {
                print("loading new URL: \(u)")
                webView.load(URLRequest(url: u))
            }
        }
    }
    
    init(webView: WKWebView) {
        self.webView = webView
    }
    
    init() {
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = false
        let preferences = WKPreferences()
        preferences.isTextInteractionEnabled = false
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.defaultWebpagePreferences = pagePreferences
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 225), configuration: configuration)
        webView.pageZoom = 0.05
    }
    
    func makeNSView(context: Context) -> WKWebView {
        webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.updateConstraints()
    }
}
