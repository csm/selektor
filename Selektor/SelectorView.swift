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
    @State var url: String = "" {
        didSet { onChange() }
    }
    @State var intervalNumber: String = "1"
    @State var intervalUnits: TimeUnit = .Hours
    @State var selectors: String = ""
    @State var resultIndex: String = "1" {
        didSet { onChange() }
    }
    @State var decodeAs: ResultType = .String {
        didSet { onChange() }
    }
    @State var lastResult: Result? = Result.StringResult(string: "")
    @State var resultPreview: String = ""
    @State var lastError: Error? = nil
    @State var showAlert: Bool = false
    @State var errorText: String = ""
    
    var body: some View {
        List {
            TextField("Name", text: $name).textInputAutocapitalization(.words)
            VStack(alignment: .leading) {
                Text("URL").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                HStack {
                    Text("https://").foregroundColor(.gray)
                    TextField("URL", text: $url).keyboardType(.URL).autocorrectionDisabled(true).textInputAutocapitalization(.never)
                }
            }
            VStack(alignment: .leading) {
                Text("Refresh Interval").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                HStack {
                    TextField("Frequency", text: $intervalNumber).keyboardType(.numberPad).autocorrectionDisabled(true)
                    Picker("", selection: $intervalUnits) {
                        Text("Seconds").tag(TimeUnit.Seconds)
                        Text("Minutes").tag(TimeUnit.Minutes)
                        Text("Hours").tag(TimeUnit.Hours)
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
                TextField("Result", text: $resultIndex).keyboardType(.numberPad).frame(width: 42)
            }
            HStack {
                Text("Decode As").font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                Spacer()
                Picker("", selection: $decodeAs) {
                    Text("Text").tag(ResultType.String)
                    Text("Number").tag(ResultType.Float)
                    Text("Percent").tag(ResultType.Percent)
                    //Text("Image").tag(ResultType.Image)
                }
            }
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
        }
        .alert(errorText, isPresented: $showAlert) {
            Button("OK") {}
        }
        .environment(\.defaultMinListRowHeight, 2)
        .listStyle(.grouped)
        .onAppear {
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
            self.intervalNumber = "\(config.triggerInterval)"
            if let v = self.config.triggerIntervalUnits {
                self.intervalUnits = TimeUnit.forTag(tag: v)
            }
            if let s = self.config.selector {
                self.selectors = s
            }
            self.resultIndex = "\(self.config.elementIndex + 1)"
            self.decodeAs = ResultType.from(tag: config.resultType ?? "s") ?? ResultType.String
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
            do {
                try viewContext.save()
            } catch {
                print("failed to save! \(error)")
            }
        }
    }
    
    func onChange() {
        DispatchQueue.global(qos: .background).async {
            if let u = URL(string: "https://\(url)"), let i = Int(resultIndex), !selectors.isEmpty {
                ValueSelector.shared.fetchValue(url: u, selector: selectors, resultIndex: i-1, resultType: decodeAs) { r, e in
                    print("fetched \(r) - \(e)")
                    lastResult = r
                    lastError = e
                    if let res = r {
                        switch res {
                        case let .StringResult(s): resultPreview = s
                        case let .FloatResult(f): resultPreview = "\(f)"
                        case let .PercentResult(p): resultPreview = "\(p * 100)%"
                        default: resultPreview = ""
                        }
                        lastError = nil
                    } else {
                        resultPreview = ""
                        if let err = e {
                            switch err {
                            case let ValueSelectorError.HTTPError(statusCode):
                                errorText = "Received HTTP code \(statusCode)"
                            case let ValueSelectorError.DecodeIntError(t):
                                errorText = "Could not read \"\(t)\" as an integer."
                            case let ValueSelectorError.DecodeIntError(t):
                                errorText = "Could not read \"\(t)\" as a number."
                            case let ValueSelectorError.DecodePercentError(t):
                                errorText = "Could not read \"\(t)\" as a percentage."
                            default:
                                errorText = "\(err.localizedDescription)."
                            }
                        } else {
                            errorText = "Nothing matched your selector."
                        }
                    }
                }
            }
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
