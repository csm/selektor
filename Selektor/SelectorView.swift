//
//  SelectorView.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI
import CoreData
import WebKit

class NavigationDelegateImpl: NSObject, WKNavigationDelegate {
    static var shared = NavigationDelegateImpl()
    var blocks: [any OnCommitHandler] = []
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
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

struct SelectorView: View, OnCommitHandler {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var config: Config
    
    @State var name: String = ""
    @State var url: String = ""
    @State var intervalNumber: String = "1"
    @State var intervalUnits: TimeUnit = .Days
    @State var selectors: String = ""
    @State var highlightedSelectors: String? = nil
    @State var resultIndex: String = "1"
    @State var decodeAs: ResultType = .String
    @State var lastResult: Result? = Result.StringResult(string: "")
    @State var resultPreview: String = ""
    @State var lastError: Error? = nil
    @State var showAlert: Bool = false
    @State var errorText: String = ""
    @State var isWidget: Bool = false
    @State var wasUpdated: Bool = false
    @State var isDownloaded: Bool = false
    static let downloadPath = {
        let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let userDirUrl = URL(fileURLWithPath: userDir)
        return userDirUrl.appendingPathComponent("selektor-data.html")
    }()

    var webView: WKWebView? = nil
    let id = UUID().uuidString
    
    init(config: Config) {
        self.config = config
        let pagePreferences = WKWebpagePreferences()
        //pagePreferences.allowsContentJavaScript = false
        let preferences = WKPreferences()
        preferences.isTextInteractionEnabled = false
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.defaultWebpagePreferences = pagePreferences
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView?.navigationDelegate = NavigationDelegateImpl.shared
    }
    
    var body: some View {
        List {
            TextField("Name", text: $name).textInputAutocapitalization(.words)
            VStack(alignment: .leading) {
                Text("URL").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                HStack {
                    Text("https://").foregroundColor(.gray)
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            if self.url.starts(with: "https://") {
                                self.url = String(self.url.dropFirst(8))
                            }
                            Task(priority: .userInitiated) {
                                await self.onUrlChange()
                            }
                        }
                }
            }
            VStack(alignment: .leading) {
                Text("Refresh Interval").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                HStack {
                    TextField("Frequency", text: $intervalNumber)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled(true)
                        .onSubmit {
                            Task(priority: .userInitiated) {
                                await self.onChange()
                                
                            }
                        }
                    Picker("", selection: $intervalUnits) {
                        Text("Seconds").tag(TimeUnit.Seconds)
                        Text("Minutes").tag(TimeUnit.Minutes)
                        Text("Hours").tag(TimeUnit.Hours)
                        Text("Days").tag(TimeUnit.Days)
                    }
                }
            }
            VStack(alignment: .leading) {
                Text("Selector").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                /*TextField("Selector", text: $selectors).autocapitalization(.none).autocorrectionDisabled(true)
                    .font(.custom("Courier", fixedSize: 16)).multilineTextAlignment(.leading).lineLimit(nil).fixedSize(horizontal: true, vertical: false)
                 */
                MultilineTextField(placeholder: "Selector", text: $selectors, onCommit: {
                    Task(priority: .background) {
                        await self.onChange()
                    }
                })
            }
            HStack {
                Text("Result Number").font(.system(size: 16, weight: .black).lowercaseSmallCaps())
                Spacer()
                TextField("Result", text: $resultIndex)
                    .keyboardType(.numberPad)
                    .frame(width: 42, alignment: .trailing)
                    .onSubmit {
                        Task(priority: .userInitiated) {
                            await self.onChange()
                        }
                    }
            }
            HStack {
                Text("Decode As").font(.system(size: 16, weight: .black).lowercaseSmallCaps())
                Spacer()
                Picker("", selection: $decodeAs) {
                    Text("Text").tag(ResultType.String)
                    Text("Number").tag(ResultType.Float)
                    Text("Percent").tag(ResultType.Percent)
                    //Text("Image").tag(ResultType.Image)
                }.onSubmit {
                    Task(priority: .userInitiated) {
                        await self.onChange()
                    }
                }
            }
            Toggle("Show In Widget", isOn: $isWidget).toggleStyle(.switch).font(.system(size: 16, weight: .black).lowercaseSmallCaps())
            HStack {
                NavigationLink(destination: AlertConfigView(config: config)) {
                    HStack {
                        Text("Alerts").font(.system(size: 16, weight: .black).lowercaseSmallCaps())
                        Spacer()
                        switch config.alertType {
                        case .none:
                            Text("None").foregroundColor(.gray)
                        case .everyTime:
                            Text("Every Time").foregroundColor(.gray)
                        case .valueChanged:
                            Text("On Change").foregroundColor(.gray)
                        case let .valueIsGreaterThan(value, orEqual):
                            if orEqual {
                                Text("Greater or Equals \(value)").foregroundColor(.gray)
                            } else {
                                Text("Greater than \(value)").foregroundColor(.gray)
                            }
                        case let .valueIsLessThan(value, orEqual):
                            if orEqual {
                                Text("Less or Equals \(value)").foregroundColor(.gray)
                            } else {
                                Text("Less than \(value)").foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            VStack(alignment: .leading) {
                Text("Result").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                HStack {
                    Text(resultPreview)
                    Spacer()
                    Button(action: {
                        if self.lastError != nil || self.lastResult == nil {
                            self.showAlert = true
                        } else {
                            self.showAlert = false
                        }
                    }) {
                        Image(uiImage: UIImage(systemName: "exclamationmark.circle")!)
                            .renderingMode(.original).tint(errorForeground())
                    }.tint(errorForeground())
                }
            }
            Group {
                if isDownloaded, let v = webView {
                    WebView(webView: v)
                    //.frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 0.75)
                        .aspectRatio(1.33, contentMode: .fill)
                } else {
                    EmptyView()
                }
                NavigationLink(destination: HistoryView(id: config.id!)) {
                    Text("Result History").font(.system(size: 16, weight: .black).lowercaseSmallCaps())
                }
            }
        }
        .alert(errorText, isPresented: $showAlert) {
            Button("OK") {}
        }
        .environment(\.defaultMinListRowHeight, 2)
        .listStyle(.grouped)
        .refreshable { await self.onUrlChange() }
        .onAppear {
            NavigationDelegateImpl.shared.registerListener(listener: self)
            self.isDownloaded = false
            if let v = self.config.name {
                self.name = v
            }
            if let u = self.config.url {
                var s = u.absoluteString
                if s.starts(with: "http://") {
                    s = String(s.dropFirst(7))
                }
                if s.starts(with: "https://") {
                    s = String(s.dropFirst(8))
                }
                self.url = s
            }
            if self.config.triggerInterval <= 0 {
                self.intervalNumber = "1"
            } else {
                self.intervalNumber = "\(self.config.triggerInterval)"
            }
            if let v = self.config.triggerIntervalUnits {
                self.intervalUnits = TimeUnit.forTag(tag: v)
            }
            if let s = self.config.selector {
                self.selectors = s
            }
            self.resultIndex = "\(self.config.elementIndex + 1)"
            self.decodeAs = ResultType.from(tag: self.config.resultType ?? "s") ?? ResultType.String
            self.isWidget = self.config.isWidget
            Task(priority: .userInitiated) {
                await self.onUrlChange()
            }
        }
        .onDisappear {
            NavigationDelegateImpl.shared.unregisterListener(listener: self)
            self.config.name = self.name
            self.config.url = URL(string: "https://\(self.url)") ?? self.config.url
            self.config.triggerInterval = Int64(self.intervalNumber) ?? self.config.triggerInterval
            self.config.triggerIntervalUnits = self.intervalUnits.tag()
            self.config.selector = self.selectors
            self.config.elementIndex = (Int32(self.resultIndex) ?? 1) - 1
            self.config.resultType = self.decodeAs.tag()
            self.config.isWidget = self.isWidget
            if self.wasUpdated {
                self.config.result = self.lastResult
                self.config.lastError = self.lastError?.localizedDescription
                let newHistory = History(context: self.viewContext)
                newHistory.configId = self.config.id
                newHistory.id = UUID()
                newHistory.date = Date()
                newHistory.result = self.lastResult
                newHistory.error = self.lastError?.localizedDescription
            }
            do {
                try self.viewContext.save()
            } catch {
                print("failed to save! \(error)")
            }
            if self.wasUpdated {
                let historyRequest = NSFetchRequest<History>(entityName: "History")
                historyRequest.predicate = NSPredicate(format: "configId = %@", argumentArray: [self.config.id!])
                historyRequest.sortDescriptors = [NSSortDescriptor(keyPath: \History.date, ascending: true)]
                do {
                    let history = try self.viewContext.fetch(historyRequest)
                    if history.count > 20 {
                        history.dropLast(20).forEach { e in
                            self.viewContext.delete(e)
                        }
                        try self.viewContext.save()
                    }
                } catch {
                    print("couldn't update history! \(error)")
                }
            }
            Scheduler.shared.scheduleConfigs()
        }
    }
    
    func onUrlChange() async {
        if let u = URL(string: "https://\(url)"), let i = Int(resultIndex), let s = selectors.notBlank() {
            var request = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20.0)
            request.setValue(lynxUserAgent, forHTTPHeaderField: "User-agent")
            request.setValue("en", forHTTPHeaderField: "Accept-Language")
            request.setValue("text/html, text/plain, text/sgml, text/css, application/xhtml+xml, */*;q=0.01", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await URLSession.shared.download(for: request)
                if let r = response as? HTTPURLResponse {
                    switch r.statusCode {
                    case 200:
                        isDownloaded = true
                        do {
                            try FileManager.default.removeItem(at: SelectorView.downloadPath)
                        } catch {
                            print("ignoring error deleting \(SelectorView.downloadPath): \(error)")
                        }
                        try FileManager.default.copyItem(at: data, to: SelectorView.downloadPath)
                        lastResult = try ValueSelector.applySelector(location: SelectorView.downloadPath, selector: s, resultIndex: i-1, resultType: decodeAs)
                        lastError = nil
                        resultPreview = lastResult?.description() ?? ""
                        DispatchQueue.main.async {
                            var request = URLRequest(url: SelectorView.downloadPath, cachePolicy: .reloadIgnoringLocalCacheData)
                            request.attribution = .user
                            self.webView?.load(request)
                        }
                    default:
                        isDownloaded = true
                        lastError = ValueSelectorError.HTTPError(statusCode: r.statusCode)
                        lastResult = nil
                        resultPreview = ""
                    }
                } else {
                    isDownloaded = true
                    lastError = nil
                    lastResult = nil
                    resultPreview = ""
                }
            } catch {
                do {
                    try FileManager.default.removeItem(at: SelectorView.downloadPath)
                } catch {
                    print("failed to delete \(SelectorView.downloadPath): \(error)")
                }
                isDownloaded = true
                lastError = error
                lastResult = nil
                resultPreview = ""
            }
        }
    }
    
    func onChange() async {
        if isDownloaded {
            self.highlightWebView()
            if let s = selectors.notBlank(), let i = Int(resultIndex) {
                do {
                    lastResult = try ValueSelector.applySelector(location: SelectorView.downloadPath, selector: s, resultIndex: i, resultType: decodeAs)
                    lastError = nil
                    resultPreview = lastResult?.description() ?? ""
                } catch {
                    lastResult = nil
                    lastError = error
                    resultPreview = ""
                }
            }
        } else {
            await onUrlChange()
        }
    }
    
    func errorForeground() -> Color {
        if lastError != nil {
            return .red
        }
        if lastResult == nil {
            return .yellow
        }
        return .clear
    }
    
    func doRefresh() {
    }
    
    func highlightWebView() {
        if let s = self.selectors.notBlank(), let i = Int(self.resultIndex) {
            let clearCode: String
            if let prev = self.highlightedSelectors {
                clearCode = """
var oldElement = document.querySelectorAll("\(prev)")[\(i - 1)];
if (oldElement) {
  oldElement.style.outline = null;
  oldElement.style.boxShadow = null;
}
"""
            } else {
                clearCode = ""
            }
            let jsCode = """
\(clearCode)
var element = document.querySelectorAll("\(s)")[\(i - 1)];
if (element) {
  element.style.outline = "#cc0 2px solid";
  element.style.boxShadow = "0 0 0 1000vmax rgba(0, 0, 0, .3);
}
"""
            webView?.evaluateJavaScript(jsCode)
            self.highlightedSelectors = self.selectors
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        highlightWebView()
    }
    
    func onCommit(webView: WKWebView) {
        highlightWebView()
    }
    
    func isEqual(that: OnCommitHandler) -> Bool {
        return id == that.id
    }
}

struct SelectorView_Previews: PreviewProvider {
    static var previews: some View {
        SelectorView(config: createConfig()).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
    
    static func createConfig() -> Config {
        let config = Config(context: PersistenceController.preview.container.viewContext)
        config.name = "Config"
        config.index = 1
        return config
    }
}
