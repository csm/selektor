//
//  SelectorView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/3/23.
//

import SwiftUI

struct SelectorView: View {
    var viewContext: NSManagedObjectContext {
        get { PersistenceController.shared.container.viewContext }
    }
    
    @ObservedObject var config: Config
    
    var saveConfig: () -> Void = {}
    
    @State var isDownloaded = false
    
    @State var lastError: Error? = nil
    @State var errorText: String = ""
    @State var lastResult: Result? = nil
    @State var showingError: Bool = false
    @State var showingAlertConfig: Bool = false
    
    static let downloadPath = {
        let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let userDirUrl = URL(fileURLWithPath: userDir)
        return userDirUrl.appendingPathComponent("selektor-data.html")
    }()
    
    init(config: Config) {
        self.config = config
        self.saveConfig = debounce(interval: 5000, queue: .main, action: self.doSaveConfig)
    }
    
    var mainConfigs: some View {
        Group {
            HStack {
                Spacer()
                Button("Delete") {
                    PersistenceController.shared.deleteConfig(config: config)
                }.foregroundColor(.red)
            }
            TextField("", text: ($config.name).safeBinding(defaultValue: "")).onSubmit {
                PersistenceController.shared.deleteConfig(config: config)
                saveConfig()
            }
            HStack {
                Text("https://").foregroundColor(.gray)
                TextField("www.example.com/path", text: ($config.url).stringBinding()).onSubmit {
                    Task() {
                        await downloadUrl()
                    }
                    saveConfig()
                }
            }
            Text("Selector")
            MultilineTextField(placeholder: "Selector", text: ($config.selector).safeBinding(defaultValue: ""), onCommit: {
                onSelectorChange()
                saveConfig()
            })
            HStack {
                Text("Result Number")
                Spacer()
                TextField("Result Number", text: ($config.elementIndex).oneBasedStringBinding()).onSubmit {
                    onSelectorChange()
                    saveConfig()
                }
            }
        }
    }
    
    var mainConfigs2: some View {
        Group {
            HStack {
                Picker("Decode As", selection: ($config.resultType).resultTypeBinding()) {
                    Text("Text").tag(ResultType.String)
                    Text("Number").tag(ResultType.Float)
                    Text("Percent").tag(ResultType.Percent)
                }.onSubmit {
                    onSelectorChange()
                    saveConfig()
                }
            }
            HStack {
                Text("Refresh")
                Spacer()
                TextField("", text: ($config.triggerInterval).stringBinding()).onSubmit {
                    saveConfig()
                }
                Picker("", selection: ($config.triggerIntervalUnits).timeUnitBinding()) {
                    Text("Seconds").tag(TimeUnit.Seconds)
                    Text("Minutes").tag(TimeUnit.Minutes)
                    Text("Hours").tag(TimeUnit.Hours)
                    Text("Days").tag(TimeUnit.Days)
                }.onSubmit {
                    saveConfig()
                }
            }
            Toggle("Show in Widget", isOn: $config.isWidget).toggleStyle(.switch).onSubmit {
                saveConfig()
            }.scaledToFill()
        }
    }
    
    var body: some View {
        VStack {
            mainConfigs
            mainConfigs2
            HStack {
                Button("Alert Config") {
                    showingAlertConfig = true
                    //AlertConfigView(config: config)
                        //.environment(\.managedObjectContext, viewContext)
                        //.padding(.all)
                        //.openWindow(with: "Alert Config", level: .statusBar, size: CGSize(width: 320, height: 240))
                }
                Spacer()
                switch config.alertType {
                case .none:
                    Text("None")
                case .everyTime:
                    Text("Every Time")
                case .valueChanged:
                    Text("On Change")
                case let .valueIsGreaterThan(value, orEquals):
                    if orEquals {
                        Text("Greater than or equals \(value.description)")
                    } else {
                        Text("Greater than \(value.description)")
                    }
                case let.valueIsLessThan(value, orEquals):
                    if orEquals {
                        Text("Less than or equals \(value.description)")
                    } else {
                        Text("Less than \(value.description)")
                    }
                }
            }
            VStack {
                HStack {
                    Text("Result Preview")
                    Spacer()
                    if lastError != nil {
                        Button(action: {  }) {
                            Image(nsImage: NSImage(systemSymbolName: "exclamationmark.circle", accessibilityDescription: "Error")!)
                        }
                    } else {
                        Text(config.result?.description() ?? "")
                    }
                }
                HStack {
                    Button("Open Browser") {
                        SelectorPreviewView(config: config)
                            .padding(.all)
                            .environment(\.managedObjectContext, viewContext)
                            .openWindow(with: "Browser", level: .modalPanel, size: CGSize(width: 720, height: 480))
                    }
                    Spacer()
                }
            }
            Spacer()
        }.onAppear {
            Task() {
                await downloadUrl()
            }
        }.sheet(isPresented: $showingError) {
            VStack {
                Text(errorText)
                Spacer()
                Button("OK") {
                    showingError = false
                }
            }
        }.sheet(isPresented: $showingAlertConfig, onDismiss: { saveConfig() }) {
            AlertConfigView(config: config)
                .environment(\.managedObjectContext, viewContext)
                .padding(.all)
        }
    }
    
    func downloadUrl() async {
        if let url = config.url {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20.0)
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
                        onSelectorChange()
                    default:
                        isDownloaded = true
                        lastError = ValueSelectorError.HTTPError(statusCode: r.statusCode)
                        lastResult = nil
                        errorText = "Error fetching web page, code \(r.statusCode)."
                    }
                } else {
                    isDownloaded = true
                    lastError = ValueSelectorError.BadInputError
                    lastResult = nil
                    errorText = "Unexpected response retrieving web page."
                }
            } catch {
                lastError = error
                lastResult = nil
            }
        }
    }
    
    func onSelectorChange() {
        if isDownloaded {
            if let selector = config.selector?.notBlank() {
                let type = ResultType.from(tag: config.resultType) ?? .String
                do {
                    lastResult = try ValueSelector.applySelector(location: SelectorView.downloadPath, selector: selector, resultIndex: Int(config.elementIndex), resultType: type)
                    lastError = nil
                    errorText = ""
                } catch {
                    lastResult = nil
                    lastError = error
                    errorText = error.localizedDescription
                }
            }
        } else {
            Task() {
                await downloadUrl()
            }
        }
    }
    
    func doSaveConfig() {
        do {
            try viewContext.save()
        } catch {
            logger.warning("error saving config: \(error)")
        }
        Scheduler.shared.scheduleConfigs()
    }
}

struct SelectorView_Previews: PreviewProvider {
    static var previews: some View {
        SelectorView(config: Config())
    }
}
