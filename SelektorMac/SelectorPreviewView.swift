//
//  SelectorPreviewView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/14/23.
//

import RealmSwift
import SwiftUI
import WebKit

struct SelectorPreviewView: View, OnCommitHandler, OnScriptResultHandler {
    @Environment(\.window) var window
    @Environment(\.realm) var realm
    
    var id: String {
        get { config.id.stringValue }
    }
    @ObservedRealmObject var config: ConfigV2
    @State var highlightedSelector: String? = nil
    @State var highlightedIndex: Int = 0
    @State var result: Result? = nil
    @State var selector: String = ""
    @State var resultIndex: Int = 0
    private let webView: WKWebView
    private let monitorClicksJs: String
    
    static let downloadDir = {
        let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let dir = URL(fileURLWithPath: userDir).appendingPathComponent("preview")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            logger.warning("could not create preview download dir \(dir): \(error)")
        }
        return dir
    }()
    static let downloadPath = {
        return downloadDir.appendingPathComponent("selektor-preview.html")
    }()
    
    init(config: ConfigV2) {
        self.config = config
        let pagePreferences = WKWebpagePreferences()
        let preferences = WKPreferences()
        preferences.isTextInteractionEnabled = false
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.defaultWebpagePreferences = pagePreferences
        monitorClicksJs = try! String(contentsOf: Bundle.main.url(forResource: "elementPath", withExtension: "js")!)
        let contentController = WKUserContentController()
        let userScript = WKUserScript(source: monitorClicksJs, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(userScript)
        contentController.add(ScriptMessageHandlerImpl.shared, name: "clickElement")
        configuration.userContentController = contentController
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.navigationDelegate = NavigationDelegateImpl.shared
        self.webView.loadHTMLString(emptyHtml, baseURL: nil)
    }

    var body: some View {
        VStack {
            HStack{
                Spacer()
                Button("Cancel") {
                    window?.close()
                }
                Button("OK") {
                    do {
                        try realm.write {
                            if let config = config.thaw() {
                                config.selector = selector
                                config.elementIndex = resultIndex
                            }
                        }
                    } catch {
                        logger.warning("could not save: \(error)")
                    }
                    window?.close()
                }
            }
            MultilineTextField(placeholder: "selector", text: $selector)
            HStack {
                Text("Result Index")
                TextField("Result Index", text: $resultIndex.oneBasedStringBinding())
            }
            Text("Result Preview \(result?.formatted() ?? "")")
            Divider()
            WebView(webView: webView)
        }.onAppear {
            self.selector = config.selector
            self.resultIndex = config.elementIndex
            Task() {
                await downloadUrl()
            }
            ScriptMessageHandlerImpl.shared.registerHandler(handler: self)
            NavigationDelegateImpl.shared.registerListener(listener: self)
        }.onDisappear {
            ScriptMessageHandlerImpl.shared.unregisterHandler(handler: self)
            NavigationDelegateImpl.shared.unregisterListener(listener: self)
        }
    }
    
    func handleDownload(result: (URL, URLResponse)) throws {
        guard let htmlData = String(data: try Data(contentsOf: result.0), encoding: DownloadManager.stringEncoding(response: result.1)) else {
            return
        }
        let html = try removeScriptTags(html: htmlData)
        do {
            try FileManager.default.removeItem(at: SelectorPreviewView.downloadPath)
        } catch {
            logger.info("could not remove \(SelectorPreviewView.downloadPath): \(error)")
        }
        try html.write(to: SelectorPreviewView.downloadPath, atomically: false, encoding: .utf8)
        var request2 = URLRequest(url: SelectorPreviewView.downloadPath)
        request2.attribution = .user
        webView.loadHTMLString(html, baseURL: nil)
        //_ = webView.loadFileRequest(request2, allowingReadAccessTo: SelectorPreviewView.downloadDir)
    }
    
    func downloadUrl() async {
        if let url = config.url {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30.0)
            request.setValue(safariUserAgent, forHTTPHeaderField: "User-agent")
            request.setValue("text/html, text/plain, text/sgml, text/css, application/xhtml+xml, */*;q=0.01", forHTTPHeaderField: "Accept")
            request.setValue("en", forHTTPHeaderField: "Accept-Language")
            do {
                if let result = try await DownloadManager.shared.foregroundSession?.download(for: request) {
                    try handleDownload(result: result)
                }
            } catch {
                logger.warning("could not download \(url): \(error)")
            }
        }
    }
    
    func onSelectorChange() async {
        do {
            if let s = selector.notBlank() {
                if let elementText = try await webView.evaluateJavaScript("document.querySelectorAll(\"\(s)\")[\(resultIndex)].innerHTML;") as? String {
                    result = try? ValueSelector.decodeResult(text: elementText, resultType: config.resultType)
                }
            }
            await runHighlighter()
        } catch {
            logger.warning("error running selector change: \(error)")
        }
    }
    
    func runHighlighter() async {
        if let s = self.selector.notBlank() {
            let clearCode: String
            if let prev = self.highlightedSelector {
                clearCode = """
var oldElement = document.querySelectorAll("\(prev)")[\(highlightedIndex)];
if (oldElement) {
  oldElement.style.outline = null;
  //oldElement.style.boxShadow = null;
}
"""
            } else {
                clearCode = ""
            }
            let jsCode = """
\(clearCode)
var element = document.querySelectorAll("\(s)")[\(resultIndex)];
if (element) {
  element.style.outline = "10000vmax solid rgba(0, 0, 0, .5)";
  //element.style.boxShadow = "0 0 0 1000vmax rgba(0, 0, 0, .5)";
}
true;
"""
            logger.debug("evaluating javascript: \(jsCode)")
            do {
                let result = try await webView.evaluateJavaScript(jsCode)
                logger.debug("JS highlighter result: \(result)")
            } catch {
                logger.error("JS highlighter error: \(error)")
            }
            self.highlightedSelector = self.selector
            self.highlightedIndex = resultIndex
        } else {
            logger.info("don't run highlighter, no selector \(selector)")
        }
    }
    
    func isEqual(that: OnCommitHandler) -> Bool {
        id == that.id
    }
    
    func isEqual(that: OnScriptResultHandler) -> Bool {
        id == that.id
    }
    
    func onCommit(webView: WKWebView) {
        logger.debug("onCommit")
        Task() {
            await onSelectorChange()
        }
    }
    
    func onScriptResult(text: String) {
        logger.debug("selected \(text)")
        let decoder = JSONDecoder()
        do {
            if let d = text.data(using: .utf8) {
                let result = try decoder.decode(ElementSelectResult.self, from: d)
                self.selector = result.selector
                resultIndex = Int(result.index)
                Task() { await onSelectorChange() }
            } else {
                logger.warning("couldn't encode \(text) as data")
            }
        } catch {
            logger.warning("could not decode result from javaScript: \(error)")
        }
    }
}

struct SelectorPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        SelectorPreviewView(config: ConfigV2(index: 0, name: "Test Config"))
    }
}
