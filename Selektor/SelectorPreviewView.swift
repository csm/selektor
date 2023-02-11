//
//  SelectorPreviewView.swift
//  Selektor
//
//  Created by Casey Marshall on 12/21/22.
//

import SwiftUI
import WebKit
import RealmSwift

struct SelectorPreviewView: View, OnCommitHandler, OnScriptResultHandler {
    @Environment(\.dismiss) var dismiss
    @Environment(\.realm) var realm
    
    @ObservedRealmObject var config: ConfigV2

    @State var selector: String = ""
    @State var highlightedSelector: String? = nil
    @State var highlightedIndex: Int = 0
    @State var result: Result? = nil
    @State var url: URL? = nil
    @State var elementIndex: Int = 0
    private let webView: WKWebView
    private let monitorClicksJs: String
    
    static let downloadDir = {
        let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let dir = URL(fileURLWithPath: userDir).appendingPathComponent("preview")
        do {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir) {
                if !isDir.boolValue {
                    try FileManager.default.removeItem(at: dir)
                }
            }
        } catch {
            logger.warning("could not remove existing file: \(error)")
        }
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
            HStack {
                Button("Cancel") {
                    NavigationDelegateImpl.shared.unregisterListener(listener: self)
                    ScriptMessageHandlerImpl.shared.unregisterHandler(handler: self)
                    dismiss()
                }
                Spacer()
                Button ("OK") {
                    NavigationDelegateImpl.shared.unregisterListener(listener: self)
                    ScriptMessageHandlerImpl.shared.unregisterHandler(handler: self)
                    do {
                        try realm.write {
                            let update = realm.object(ofType: ConfigV2.self, forPrimaryKey: config.id)
                            update?.selector = selector
                            update?.elementIndex = elementIndex
                        }
                    } catch {
                        logger.error("could not save config: \(error)")
                    }
                    dismiss()
                }
            }.padding([.leading, .trailing, .top], 20)
            MultilineTextField(placeholder: "", text: $selector) {
                Task() { await onSelectorChange() }
            }.padding(.all, 8)
            Divider()
            HStack {
                Text("Element Index").font(labelFont)
                Spacer()
                TextField(text: $elementIndex.oneBasedStringBinding()) {
                    Text("Result Index")
                }.frame(maxWidth: 100, alignment: .trailing)
                    .keyboardType(.numberPad)
            }.padding(.all, 8)
            Divider()
            HStack {
                Text("Result").font(labelFont)
                Spacer()
                Text(result?.formatted() ?? "").foregroundColor(.gray)
            }.padding(.all, 8)
            //}.listStyle(.grouped)
            WebView(webView: webView).frame(maxWidth: 10000, maxHeight: 10000)
        }.onAppear {
            NavigationDelegateImpl.shared.registerListener(listener: self)
            ScriptMessageHandlerImpl.shared.registerHandler(handler: self)
            self.selector = config.selector
            self.elementIndex = config.elementIndex
            self.url = config.url
            if let u = url {
                Task() { await downloadPage(url: u) }
            }
        }
    }
    
    var id: String {
        get { config.id.stringValue }
    }
    
    func isEqual(that: OnCommitHandler) -> Bool {
        if let that = that as? SelectorPreviewView {
            return that.id == id
        }
        return false
    }
    
    func isEqual(that: OnScriptResultHandler) -> Bool {
        if let that = that as? SelectorPreviewView {
            return that.id == id
        }
        return false
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
    
    func downloadPage(url: URL) async {
        var request = URLRequest(url: url)
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
    
    func onCommit(webView: WKWebView) {
        Task() { await onSelectorChange() }
    }
    
    func onScriptResult(text: String) {
        logger.info("selected \(text)")
        let decoder = JSONDecoder()
        do {
            if let d = text.data(using: .utf8) {
                let selectResult = try decoder.decode(ElementSelectResult.self, from: d)
                self.selector = selectResult.selector
                self.elementIndex = selectResult.index
                Task() { await onSelectorChange() }
            } else {
                logger.warning("couldn't encode \(text) as data")
            }
        } catch {
            logger.warning("could not decode result from javaScript: \(error)")
        }
    }
    
    func onSelectorChange() async {
        do {
            if let s = selector.notBlank() {
                if let elementText = try await webView.evaluateJavaScript("document.querySelectorAll(\"\(s)\")[\(elementIndex)].innerHTML;") as? String {
                    result = try? ValueSelector.decodeResult(text: elementText, resultType: config.resultType)
                }
            }
            runHighlighter()
        } catch {
            logger.warning("error running selector change: \(error)")
        }
    }
    
    func runHighlighter() {
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
var element = document.querySelectorAll("\(s)")[\(elementIndex)];
if (element) {
  element.style.outline = "10000vmax solid rgba(0, 0, 0, .5)";
  //element.style.boxShadow = "0 0 0 1000vmax rgba(0, 0, 0, .5)";
}
true;
"""
            // logger.debug("evaluating javascript: \(jsCode)")
            webView.evaluateJavaScript(jsCode) { result, error in
                logger.notice("JS highlighter execution result \(String(describing: result)) error \(error)")
            }
            self.highlightedSelector = self.selector
            self.highlightedIndex = elementIndex
            let queryCode = """
document.querySelectorAll("\(s)")[\(elementIndex)]
"""
        }
    }
    
    let labelFont = Font.headline
}

struct SelectorPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        SelectorPreviewView(config: {
            let config = ConfigV2(index: 0, name: "Test Config")
            config.url = URL(string: "https://duckduckgo.com/")
            return config
        }())
    }
}
