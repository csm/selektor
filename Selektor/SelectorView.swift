//
//  SelectorView.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI
import CoreData
import WebKit

struct SelectorView: View {
    @Environment(\.presentationMode) private var presentationMode
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
    @State var showPreview: Bool = false
    static let downloadPath = {
        let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let userDirUrl = URL(fileURLWithPath: userDir)
        return userDirUrl.appendingPathComponent("selektor-data.html")
    }()
    @State var lastEncoding: String.Encoding = .utf8
    
    let id = UUID().uuidString
    
    var body: some View {
        List {
#if os(macOS)
            HStack {
                Button("Back") {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
#endif
            self.configControls
            VStack(alignment: .leading) {
                Text("Result Preview").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
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
                        Label("", systemImage: "exclamationmark.circle").foregroundColor(errorForeground())
                    }.tint(errorForeground())
                }
            }
            Group {
                NavigationLink(destination: HistoryView(id: config.id!, name: config.name!)) {
                    Text("Result History").font(.system(size: 16, weight: .black).lowercaseSmallCaps())
                }
                Button(action: { showPreview = true }) {
                    Text("Preview").font(.system(size: 16, weight: .black).lowercaseSmallCaps())
                }.foregroundColor(.primary)
            }
        }
        .alert(errorText.notBlank() ?? "No value could be read.", isPresented: $showAlert) {
            Button("OK") {}
        }
        .sheet(isPresented: $showPreview, onDismiss: {
            showPreview = false
            self.selectors = config.selector ?? ""
        }) {
            SelectorPreviewView(config: config)
        }
        .environment(\.defaultMinListRowHeight, 2)
#if os(macOS)
        .listStyle(.automatic)
#else
        .listStyle(.grouped)
#endif
        .refreshable { await self.onUrlChange() }
        .onAppear {
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
            if let v = self.config.triggerIntervalUnits {
                self.intervalUnits = TimeUnit.forTag(tag: v)
                switch self.intervalUnits {
                case .Hours, .Days: break
                default:
                    self.intervalUnits = .Hours
                }
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
            config.name = self.name
            config.url = URL(string: "https://\(self.url)") ?? self.config.url
            config.triggerInterval = 1
            config.triggerIntervalUnits = self.intervalUnits.tag()
            config.selector = self.selectors
            config.elementIndex = (Int32(self.resultIndex) ?? 1) - 1
            config.resultType = self.decodeAs.tag()
            config.isWidget = self.isWidget
            do {
                try viewContext.save()
            } catch {
                logger.error("failed to save! \(error)")
            }
            /*if isWidget {
                do {
                    let request = NSFetchRequest<Config>(entityName: "Config")
                    request.predicate = NSPredicate(format: "id != %@ AND isWidget == TRUE", argumentArray: [config.id!])
                    let results = try viewContext.fetch(request)
                    if !results.isEmpty {
                        results.forEach { e in e.isWidget = false }
                        try viewContext.save()
                    }
                } catch {
                    logger.error("failed to update isWidget on other configs: \(error)")
                }
            }*/
            Scheduler.shared.scheduleConfigs()
        }
    }
    
    var configControls: some View {
        Group {
            TextField("Name", text: $name)
#if os(iOS)
                .textInputAutocapitalization(.words)
#endif
            VStack(alignment: .leading) {
                Text("URL").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                HStack {
                    Text("https://").foregroundColor(.gray)
                    TextField("URL", text: $url)
#if os(iOS)
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
#endif
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
                HStack {
                    Text("Refresh").font(.system(size: 16, weight: .black).lowercaseSmallCaps())
                    Picker("", selection: $intervalUnits) {
                        Text("Hourly").tag(TimeUnit.Hours)
                        Text("Daily").tag(TimeUnit.Days)
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
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
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
                                Text("Greater or Equals \(value.description)").foregroundColor(.gray)
                            } else {
                                Text("Greater than \(value.description)").foregroundColor(.gray)
                            }
                        case let .valueIsLessThan(value, orEqual):
                            if orEqual {
                                Text("Less or Equals \(value.description)").foregroundColor(.gray)
                            } else {
                                Text("Less than \(value.description)").foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
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
                            logger.error("ignoring error deleting \(SelectorView.downloadPath): \(error)")
                        }
                        try FileManager.default.copyItem(at: data, to: SelectorView.downloadPath)
                        lastEncoding = DownloadManager.stringEncoding(response: response)
                        lastResult = try ValueSelector.applySelector(location: SelectorView.downloadPath, selector: s, resultIndex: i-1, resultType: decodeAs, documentEncoding: DownloadManager.stringEncoding(response: response))
                        lastError = nil
                        errorText = ""
                        resultPreview = lastResult?.description() ?? ""
                    default:
                        isDownloaded = true
                        lastError = ValueSelectorError.HTTPError(statusCode: r.statusCode)
                        lastResult = nil
                        resultPreview = ""
                        errorText = "Error fetching web page, code \(r.statusCode)."
                    }
                } else {
                    isDownloaded = true
                    lastError = nil
                    lastResult = nil
                    resultPreview = ""
                    errorText = "Unexpected response retrieving web page."
                }
            } catch {
                do {
                    try FileManager.default.removeItem(at: SelectorView.downloadPath)
                } catch {
                    logger.error("failed to delete \(SelectorView.downloadPath): \(error)")
                }
                isDownloaded = true
                lastError = error
                lastResult = nil
                resultPreview = ""
                errorText = error.localizedDescription
            }
        }
    }
    
    func onChange() async {
        if isDownloaded {
            if let s = selectors.notBlank(), let i = Int(resultIndex) {
                do {
                    lastResult = try ValueSelector.applySelector(location: SelectorView.downloadPath, selector: s, resultIndex: i-1, resultType: decodeAs, documentEncoding: lastEncoding)
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
