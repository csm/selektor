//
//  WebView.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    typealias UIViewType = WKWebView
    
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
webView = WKWebView(frame: .zero, configuration: configuration)
        webView.pageZoom = 0.05
    }
    
    func makeUIView(context: Context) -> WKWebView {
        webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
