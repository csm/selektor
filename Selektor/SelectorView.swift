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
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var config: Config
    
    @State var name: String = ""
    @State var url: String = ""
    @State var intervalNumber: String = "1"
    @State var intervalUnits: TimeUnit = .Days
    @State var selectors: String = ""
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
                            if url.starts(with: "https://") {
                                url = String(url.dropFirst(8))
                            }
                            onUrlChange()
                        }
                }
            }
            VStack(alignment: .leading) {
                Text("Refresh Interval").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                HStack {
                    TextField("Frequency", text: $intervalNumber)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled(true)
                        .onSubmit { onChange() }
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
                MultilineTextField(placeholder: "Selector", text: $selectors, onCommit: onChange)
            }
            HStack {
                Text("Result Number").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                Spacer()
                TextField("Result", text: $resultIndex)
                    .keyboardType(.numberPad)
                    .frame(width: 42, alignment: .trailing)
                    .onSubmit {
                        onChange()
                    }
            }
            HStack {
                Text("Decode As").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                Spacer()
                Picker("", selection: $decodeAs) {
                    Text("Text").tag(ResultType.String)
                    Text("Number").tag(ResultType.Float)
                    Text("Percent").tag(ResultType.Percent)
                    //Text("Image").tag(ResultType.Image)
                }.onSubmit {
                    onChange()
                }
            }
            Toggle("Show In Widget", isOn: $isWidget).toggleStyle(.switch)
            VStack(alignment: .leading) {
                Text("Result").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                HStack {
                    Text(resultPreview)
                    Spacer()
                    Button(action: {
                        if lastError != nil || lastResult == nil {
                            showAlert = true
                        } else {
                            showAlert = false
                        }
                    }) {
                        Image(uiImage: UIImage(systemName: "exclamationmark.circle")!)
                            .renderingMode(.original).tint(errorForeground())
                    }.tint(errorForeground())
                }
            }
            NavigationLink("Result History", value: self.config.id)
        }
        .navigationDestination(for: UUID.self) { id in
            HistoryView(id: id)
        }
        .alert(errorText, isPresented: $showAlert) {
            Button("OK") {}
        }
        .environment(\.defaultMinListRowHeight, 2)
        .listStyle(.grouped)
        .onAppear {
            isDownloaded = false
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
            if config.triggerInterval <= 0 {
                self.intervalNumber = "1"
            } else {
                self.intervalNumber = "\(config.triggerInterval)"
            }
            if let v = self.config.triggerIntervalUnits {
                self.intervalUnits = TimeUnit.forTag(tag: v)
            }
            if let s = self.config.selector {
                self.selectors = s
            }
            self.resultIndex = "\(self.config.elementIndex + 1)"
            self.decodeAs = ResultType.from(tag: config.resultType ?? "s") ?? ResultType.String
            self.isWidget = self.config.isWidget
            onChange()
        }
        .onDisappear {
            config.name = self.name
            config.url = URL(string: "https://\(self.url)") ?? config.url
            config.triggerInterval = Int64(self.intervalNumber) ?? config.triggerInterval
            config.triggerIntervalUnits = self.intervalUnits.tag()
            config.selector = self.selectors
            config.elementIndex = (Int32(resultIndex) ?? 1) - 1
            config.resultType = decodeAs.tag()
            config.isWidget = self.isWidget
            if wasUpdated {
                config.result = lastResult
                config.lastError = lastError?.localizedDescription
                let newHistory = History(context: viewContext)
                newHistory.configId = config.id
                newHistory.id = UUID()
                newHistory.date = Date()
                newHistory.result = lastResult
                newHistory.error = lastError?.localizedDescription
            }
            do {
                try viewContext.save()
            } catch {
                print("failed to save! \(error)")
            }
            if wasUpdated {
                let historyRequest = NSFetchRequest<History>(entityName: "History")
                historyRequest.predicate = NSPredicate(format: "configId = %@", argumentArray: [config.id!])
                historyRequest.sortDescriptors = [NSSortDescriptor(keyPath: \History.date, ascending: true)]
                do {
                    let history = try viewContext.fetch(historyRequest)
                    if history.count > 20 {
                        history.dropLast(20).forEach { e in
                            viewContext.delete(e)
                        }
                        try viewContext.save()
                    }
                } catch {
                    print("couldn't update history! \(error)")
                }
            }
            Scheduler.shared.scheduleConfigs()
        }
    }
    
    func onUrlChange() {
        DispatchQueue.global(qos: .background).async {
            if let u = URL(string: "https://\(url)"), let i = Int(resultIndex), !selectors.isEmpty {
                var request = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20.0)
                request.setValue(lynxUserAgent, forHTTPHeaderField: "User-agent")
                request.setValue("en", forHTTPHeaderField: "Accept-Language")
                request.setValue("text/html, text/plain, text/sgml, text/css, application/xhtml+xml, */*;q=0.01", forHTTPHeaderField: "Accept")
                URLSession.shared.downloadTask(with: request) { location, response, error in
                    if let e = error {
                        lastResult = nil
                        lastError = e
                        resultPreview = ""
                    } else if let r = response as? HTTPURLResponse, let loc = location {
                        switch r.statusCode {
                        case 200:
                            isDownloaded = true
                            do {
                                try FileManager.default.copyItem(atPath: loc.absoluteString, toPath: SelectorView.downloadPath.absoluteString)
                                onChange()
                            } catch {
                                lastResult = nil
                                lastError = error
                                resultPreview = ""
                            }
                        default:
                            lastResult = nil
                            lastError = ValueSelectorError.HTTPError(statusCode: r.statusCode)
                            resultPreview = ""
                        }
                    }
                }
                ValueSelector.shared.fetchValue(url: u, selector: selectors, resultIndex: i, resultType: decodeAs) { result, error in
                    lastResult = result
                    lastError = error
                    resultPreview = result?.description() ?? ""
                    wasUpdated = true
                }
            }
        }
    }
    
    func onChange() {
        if isDownloaded {
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
            onUrlChange()
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
