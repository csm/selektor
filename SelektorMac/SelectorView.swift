//
//  SelectorView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/3/23.
//

import RealmSwift
import SwiftUI

struct SelectorView: View {
    @Environment(\.realm) var realm
    
    @ObservedRealmObject var config: ConfigV2
    
    @State var isDownloaded = false
    
    @State var lastError: Error? = nil
    @State var errorText: String = ""
    @State var lastResult: Result? = nil
    @State var showingError: Bool = false
    @State var showingAlertConfig: Bool = false
    
    @State var greaterThanValue: Decimal = Decimal()
    @State var greaterThanOrEquals: Bool = false
    @State var lessThanValue: Decimal = Decimal()
    @State var lessThanOrEquals: Bool = false
    
    static let labelWidth: CGFloat = 100
    
    static let downloadPath = {
        let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let userDirUrl = URL(fileURLWithPath: userDir)
        return userDirUrl.appendingPathComponent("selektor-data.html")
    }()
    
    init(config: ConfigV2) {
        self.config = config
    }
    
    var maxIndex: Int {
        get {
            let results = realm.objects(ConfigV2.self)
            return Int(results.map { config in config.index }.max()!)
        }
    }
    
    var mainConfigs: some View {
        Group {
            TextField("", text: $config.name)
            HStack {
                Text("https://").foregroundColor(.gray)
                TextField("www.example.com/path", text: ($config.url).stringBinding()).onSubmit {
                    Task() {
                        await downloadUrl()
                    }
                }
            }
            HStack {
                Text("Selector").font(.system(.body, weight: .semibold))
                Spacer()
            }
            MultilineTextField(placeholder: "Selector", text: ($config.selector), onCommit: {
                onSelectorChange()
            })
            HStack {
                Text("Result Number").frame(width: SelectorView.labelWidth, alignment: .trailing).font(.system(.body, weight: .semibold))
                Spacer()
                TextField("Result Number", text: ($config.elementIndex).oneBasedStringBinding()).onSubmit {
                    onSelectorChange()
                }
            }
        }
    }
    
    var mainConfigs2: some View {
        Group {
            HStack {
                Text("Decode As").frame(width: SelectorView.labelWidth, alignment: .trailing).font(.system(.body, weight: .semibold))
                Picker("", selection: $config.resultType) {
                    Text("Text").tag(ResultType.String)
                    Text("Number").tag(ResultType.Float)
                    Text("Percent").tag(ResultType.Percent)
                }.onSubmit {
                    onSelectorChange()
                }
            }
            HStack {
                Text("Refresh").frame(width: SelectorView.labelWidth, alignment: .trailing).font(.system(.body, weight: .semibold))
                Spacer()
                TextField("", text: ($config.triggerInterval).valueBinding().stringBinding()).onSubmit {
                    Scheduler.shared.scheduleConfigs()
                }
                Picker("", selection: ($config.triggerInterval).unitsBinding()) {
                    Text("Seconds").tag(TimeUnit.Seconds)
                    Text("Minutes").tag(TimeUnit.Minutes)
                    Text("Hours").tag(TimeUnit.Hours)
                    Text("Days").tag(TimeUnit.Days)
                }.onSubmit {
                    Scheduler.shared.scheduleConfigs()
                }
            }
            HStack {
                Text("Show in Widget").frame(width: SelectorView.labelWidth, alignment: .trailing).font(.system(.body, weight: .semibold))
                Toggle("", isOn: $config.isWidget).toggleStyle(.switch).onSubmit {
                    do {
                        try realm.write {
                            let configs = realm.objects(ConfigV2.self)
                            configs.filter { c in c.id != config.id }.forEach { c in
                                if c.isWidget {
                                    c.isWidget = false
                                }
                            }
                        }
                    } catch {
                        logger.error("error toggling other configs off: \(error)")
                    }
                }.scaledToFill()
                Spacer()
            }
        }
    }
    
    var body: some View {
        VStack {
            mainConfigs
            mainConfigs2
            HStack(alignment: .top) {
                Text("Alert").frame(width: SelectorView.labelWidth, alignment: .trailing).font(.system(.body, weight: .semibold))
                Picker("", selection: $config.alertType) {
                    Text("None").tag(AlertType.none)
                    Text("Every Time").tag(AlertType.everyTime)
                    Text("On Change").tag(AlertType.valueChanged)
                    HStack {
                        Text("Less Than")
                        TextField("", text: $lessThanValue.stringBinding()).disabled(!isLessThan())
                            .onSubmit {
                                config.alertType = .valueIsLessThan(value: lessThanValue, orEquals: lessThanOrEquals)
                            }
                        Toggle("Or Equals", isOn: $lessThanOrEquals).toggleStyle(.checkbox).disabled(!isLessThan()).onSubmit {
                            config.alertType = .valueIsLessThan(value: lessThanValue, orEquals: lessThanOrEquals)
                        }
                    }
                    .tag(AlertType.valueIsLessThan(value: Decimal(), orEquals: false))
                    HStack {
                        Text("Greater Than")
                        TextField("", text: $greaterThanValue.stringBinding()).disabled(!isGreaterThan())
                            .onSubmit {
                                config.alertType = .valueIsGreaterThan(value: greaterThanValue, orEquals: greaterThanOrEquals)
                            }
                        Toggle("Or Equals", isOn: $greaterThanOrEquals).toggleStyle(.checkbox).disabled(!isGreaterThan()).onSubmit {
                            config.alertType = .valueIsGreaterThan(value: greaterThanValue, orEquals: greaterThanOrEquals)
                        }
                    }
                    .tag(AlertType.valueIsGreaterThan(value: Decimal(), orEquals: false))
                }.pickerStyle(.radioGroup)

                Spacer()
            }
            VStack {
                HStack {
                    Text("").frame(width: SelectorView.labelWidth)
                    Toggle(isOn: $config.alertSound) {
                        Text("Play Sound")
                    }.disabled(config.alertType == .none)
                    Spacer()
                }.padding(.bottom, 5)
                HStack {
                    Text("").frame(width: SelectorView.labelWidth)
                    Toggle(isOn: $config.alertTimeSensitive) {
                        Text("Time Sensitive")
                    }.disabled(config.alertType == .none)
                    Spacer()
                }
            }
            VStack {
                HStack(alignment: .top) {
                    Text("Result Preview").frame(width: SelectorView.labelWidth, alignment: .trailing).font(.system(.body, weight: .semibold))
                    if lastError != nil {
                        Button(action: {  }) {
                            Image(nsImage: NSImage(systemSymbolName: "exclamationmark.circle", accessibilityDescription: "Error")!)
                        }
                    } else {
                        Text(config.lastValue?.formatted() ?? "").frame(alignment: .leading)
                    }
                    Spacer()
                }
                HStack {
                    Spacer()
                    Button("Open Browser") {
                        SelectorPreviewView(config: config)
                            .padding(.all)
                            .environment(\.realm, realm)
                            .openWindow(with: "Browser", level: .modalPanel, size: CGSize(width: 720, height: 480))
                    }
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
        }
    }
    
    private func isLessThan() -> Bool {
        switch config.alertType {
        case .valueIsLessThan(_, _): return true
        default: return false
        }
    }
    
    private func isGreaterThan() -> Bool {
        switch config.alertType {
        case .valueIsGreaterThan(_, _): return true
        default: return false
        }
    }
    
    func downloadUrl() async {
        if let url = config.url {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20.0)
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
            if let selector = config.selector.notBlank() {
                let type = config.resultType
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
}

struct SelectorView_Previews: PreviewProvider {
    static var previews: some View {
        SelectorView(config: ConfigV2(index: 0, name: "Test"))
    }
}
