//
//  SelectorPreviewView.swift
//  Selektor
//
//  Created by Casey Marshall on 12/21/22.
//

import SwiftUI
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

struct SelectorPreviewView: View, OnCommitHandler, OnScriptResultHandler {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var config: Config
    @State var selector: String = ""
    @State var highlightedSelector: String? = nil
    @State var highlightedIndex: Int = 0
    @State var result: Result? = nil
    @State var url: URL? = nil
    @State var resultIndexText: String = "1"
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
    
    init(config: Config) {
        self.config = config
        let pagePreferences = WKWebpagePreferences()
        //pagePreferences.allowsContentJavaScript = false
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
                    config.selector = selector
                    if let i = Int32(resultIndexText) {
                        config.elementIndex = i - 1
                    }
                    dismiss()
                }
            }.padding([.leading, .trailing, .top], 20)
            //List {
            MultilineTextField(placeholder: "", text: $selector) {
                Task() { await onSelectorChange() }
            }.padding(.all, 8)
            Divider()
            HStack {
                Text("Element Index").font(.system(size: 16, weight: .black).lowercaseSmallCaps())
                Spacer()
                TextField(text: $resultIndexText) {
                    Text("Result Index")
                }.frame(maxWidth: 100, alignment: .trailing)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
            }.padding(.all, 8)
            Divider()
            HStack {
                Text("Result").font(.system(size: 16, weight: .black).lowercaseSmallCaps())
                Spacer()
                Text(result?.description() ?? "").foregroundColor(.gray)
            }.padding(.all, 8)
            //}.listStyle(.grouped)
            WebView(webView: webView).frame(maxWidth: 10000, maxHeight: 10000)
        }.onAppear {
            NavigationDelegateImpl.shared.registerListener(listener: self)
            ScriptMessageHandlerImpl.shared.registerHandler(handler: self)
            self.selector = config.selector ?? ""
            self.resultIndexText = "\(config.elementIndex + 1)"
            self.url = config.url
            if let u = url {
                Task() { await downloadPage(url: u) }
            }
        }
    }
    
    var id: String {
        get { config.id!.uuidString }
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
        try html.write(to: SelectorPreviewView.downloadDir, atomically: false, encoding: .utf8)
        var request2 = URLRequest(url: SelectorPreviewView.downloadPath)
        request2.attribution = .user
        webView.loadHTMLString(html, baseURL: nil)
        //_ = webView.loadFileRequest(request2, allowingReadAccessTo: SelectorPreviewView.downloadDir)
    }
    
    func downloadPage(url: URL) async {
        var request = URLRequest(url: url)
        request.setValue(lynxUserAgent, forHTTPHeaderField: "User-agent")
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
                let result = try decoder.decode(ElementSelectResult.self, from: d)
                self.selector = result.selector
                self.resultIndexText = "\(result.index + 1)"
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
            if let s = selector.notBlank(), let i = Int(resultIndexText), i > 0 {
                if let elementText = try await webView.evaluateJavaScript("document.querySelectorAll(\"\(s)\")[\(i-1)].innerHTML;") as? String {
                    result = try? ValueSelector.decodeResult(text: elementText, resultType: ResultType.from(tag: config.resultType) ?? .String)
                }
            }
            runHighlighter()
        } catch {
            logger.warning("error running selector change: \(error)")
        }
    }
    
    func runHighlighter() {
        if let s = self.selector.notBlank(), let i = Int(self.resultIndexText) {
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
var element = document.querySelectorAll("\(s)")[\(i - 1)];
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
            self.highlightedIndex = i - 1
            let queryCode = """
document.querySelectorAll("\(s)")[\(i - 1)]
"""
        }
    }
}

struct SelectorPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        SelectorPreviewView(config: {
            let config = Config(context: PersistenceController.preview.container.viewContext)
            config.url = URL(string: "https://duckduckgo.com/")
            return config
        }())
    }
}
