//
//  SelectorView.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI
import RealmSwift
import WebKit

enum NavDest: Int {
    case alertConfig = 0
    case history = 1
}

struct SelectorView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.realm) private var realm
    
    @ObservedRealmObject var config: ConfigV2
    
    @State var highlightedSelectors: String? = nil
    @State var lastResult: Result? = Result.StringResult(string: "")
    @State var resultPreview: String = ""
    @State var lastError: Error? = nil
    @State var showAlert: Bool = false
    @State var errorText: String = ""
    @State var wasUpdated: Bool = false
    @State var isDownloaded: Bool = false
    @State var showPreview: Bool = false
    static let downloadPath = {
        let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let userDirUrl = URL(fileURLWithPath: userDir)
        return userDirUrl.appendingPathComponent("selektor-data.html")
    }()
    @State var lastEncoding: String.Encoding = .utf8
    @ObservedObject var subscriptionManager: SubscriptionManager = SubscriptionManager.shared
    @State var showSubscriptionSheet: Bool = false
    
    let id = UUID().uuidString
    
    // .system(size: 16, weight: .black).lowercaseSmallCaps()
    let largeLabelFont = Font.headline
    let smallLabelFont = Font.subheadline

    var body: some View {
        List {
            self.configControls
            self.configControls2
            VStack(alignment: .leading) {
                Text("Result Preview").font(smallLabelFont)
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
                NavigationLink(
                    destination: HistoryView(id: config.id, name: config.name)
                        .environment(\.realm, try! PersistenceV2.shared.realm)
                ) {
                    Text("Result History").font(largeLabelFont)
                }
                Button(action: { showPreview = true }) {
                    Text("Show Browser").font(largeLabelFont)
                }.foregroundColor(.primary)
            }
        }
        .alert(errorText.notBlank() ?? "No value could be read.", isPresented: $showAlert) {
            Button("OK") {}
        }
        .sheet(isPresented: $showPreview, onDismiss: {
            showPreview = false
        }) {
            SelectorPreviewView(config: config)
        }
        .sheet(isPresented: $showSubscriptionSheet, onDismiss: {
            showSubscriptionSheet = false
        }) {
            SubscribeView().padding(.all)
        }
        .environment(\.defaultMinListRowHeight, 2)
        .listStyle(.grouped)
        .refreshable { await self.onUrlChange() }
        .onAppear {
            self.isDownloaded = false
            Task(priority: .userInitiated) {
                await self.onUrlChange()
            }
        }
        .onDisappear {
            Task() {
                do {
                    try await PushManager.shared.updateSchedules()
                } catch {
                    logger.error("failed to upload schedules: \(error)")
                }
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
            TextField("Name", text: $config.name)
                .textInputAutocapitalization(.words)
            VStack(alignment: .leading) {
                Text("URL").font(smallLabelFont)
                HStack {
                    Text("https://").foregroundColor(.gray)
                    TextField("URL", text: ($config.url).stringBinding())
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            Task(priority: .userInitiated) {
                                await self.onUrlChange()
                            }
                        }
                }
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Refresh").font(largeLabelFont)
                    Picker("", selection: ($config.triggerInterval).unitsBinding()) {
                        Text("Hourly").tag(TimeUnit.Hours)
                        Text("Daily").tag(TimeUnit.Days)
                    }.disabled(!subscriptionManager.isSubscribed)
                }.onTapGesture {
                    if !subscriptionManager.isSubscribed {
                        showSubscriptionSheet = true
                    }
                }
            }
            VStack(alignment: .leading) {
                Text("Selector").font(largeLabelFont)
                MultilineTextField(placeholder: "Selector", text: $config.selector, onCommit: {
                    Task(priority: .background) {
                        await self.onChange()
                    }
                })
            }
            HStack {
                Text("Result Number").font(largeLabelFont)
                Spacer()
                TextField("Result", text: ($config.elementIndex).oneBasedStringBinding())
                    .keyboardType(.numberPad)
                    .frame(width: 42, alignment: .trailing)
                    .onSubmit {
                        Task(priority: .userInitiated) {
                            await self.onChange()
                        }
                    }
            }
        }
    }
    
    var configControls2: some View {
        Group {
            HStack {
                Text("Decode As").font(largeLabelFont)
                Spacer()
                Picker("", selection: $config.resultType) {
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
            Toggle("Show In Widget", isOn: $config.isWidget)
                .toggleStyle(.switch)
                .font(largeLabelFont)
                .disabled(!subscriptionManager.isSubscribed)
                .onTapGesture {
                    if !subscriptionManager.isSubscribed {
                        showSubscriptionSheet = true
                    }
                }
            if subscriptionManager.isSubscribed {
                HStack {
                    NavigationLink(
                        destination: AlertConfigView(id: config.id)
                            .environment(\.realm, try! PersistenceV2.shared.realm)
                    ) {
                        HStack {
                            Text("Alerts").font(largeLabelFont)
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
            } else {
                HStack {
                    Text("Alerts").foregroundColor(.gray)
                    Spacer()
                    Text("None").foregroundColor(.gray)
                }.onTapGesture(count: 1) {
                    showSubscriptionSheet = true
                }
            }
        }

    }
    
    func onUrlChange() async {
        if let u = config.url, let s = config.selector.notBlank() {
            var request = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20.0)
            request.setValue(safariUserAgent, forHTTPHeaderField: "User-agent")
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
                        lastResult = try ValueSelector.applySelector(location: SelectorView.downloadPath, selector: s, resultIndex: Int(config.elementIndex), resultType: config.resultType, documentEncoding: DownloadManager.stringEncoding(response: response))
                        lastError = nil
                        errorText = ""
                        resultPreview = lastResult?.formatted() ?? ""
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
        do {
            try await PushManager.shared.updateSchedules()
        } catch {
            logger.error("could not upload schedules: \(error)")
        }
        if isDownloaded {
            if let s = config.selector.notBlank() {
                do {
                    lastResult = try ValueSelector.applySelector(location: SelectorView.downloadPath, selector: s, resultIndex: Int(config.elementIndex), resultType: config.resultType, documentEncoding: lastEncoding)
                    lastError = nil
                    resultPreview = lastResult?.formatted() ?? ""
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
        SelectorView(config: ConfigV2(index: 0, name: "Test Config")).environment(\.realm, try! PersistenceV2.preview.realm)
    }
}
