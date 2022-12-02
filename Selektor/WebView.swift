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
    
    init() {
        webView = WKWebView()
        webView.pageZoom = 0.05
    }
    
    func makeUIView(context: Context) -> WKWebView {
        webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
