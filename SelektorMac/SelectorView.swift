//
//  SelectorView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/3/23.
//

import SwiftUI

struct SelectorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var config: Config
    @State var url: String = ""
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Delete") {
                    logger.debug("delete")
                }.foregroundColor(.red)
            }
            TextField("", text: ($config.name).safeBinding(defaultValue: "")).onSubmit {
                saveConfig()
            }
            HStack {
                Text("https://").foregroundColor(.gray)
                TextField("www.example.com/path", text: ($config.url).stringBinding()).onSubmit {
                    saveConfig()
                }
            }
            Text("Selector")
            MultilineTextField(placeholder: "Selector", text: ($config.selector).safeBinding(defaultValue: ""))
            HStack {
                Picker("Decode As", selection: ($config.resultType).resultTypeBinding()) {
                    Text("Text").tag(ResultType.String)
                    Text("Number").tag(ResultType.Float)
                    Text("Percent").tag(ResultType.Percent)
                }.onSubmit {
                    saveConfig()
                }
            }
            Toggle("Show in Widget", isOn: $config.isWidget).toggleStyle(.switch).onSubmit {
                saveConfig()
            }.scaledToFill()
            HStack {
                Button("Alert Config") {
                    AlertConfigView(config: config)
                        .environment(\.managedObjectContext, viewContext)
                        .padding(.all)
                        .openWindow(with: "Alert Config", level: .statusBar, size: CGSize(width: 320, height: 240))
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
                    Text(config.result?.description() ?? "")
                }
                HStack {
                    Button("Open Browser") {
                        SelectorPreviewView(config: config).padding(.all).openWindow(with: "Browser", level: .floating, size: CGSize(width: 480, height: 480))
                    }
                    Spacer()
                }
            }
            Spacer()
        }
    }
    
    func saveConfig() {
        do {
            try viewContext.save()
        } catch {
            logger.warning("error saving config: \(error)")
        }
    }
}

struct SelectorView_Previews: PreviewProvider {
    static var previews: some View {
        SelectorView(config: Config())
    }
}
