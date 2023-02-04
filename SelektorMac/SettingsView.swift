//
//  SettingsView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/3/23.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Config.index, ascending: true)],
        animation: .default)
    private var configs: FetchedResults<Config>
    @State var selectedConfig: Config.ID? = nil
    
    var body: some View {
        NavigationSplitView {
            VStack {
                List(configs, selection: $selectedConfig) { config in
                    Text(config.name ?? "Config \(config.index)")
                }
                Spacer()
                HStack() {
                    Button(action: addConfig) {
                        Image(nsImage: NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")!)
                    }
                    Spacer()
                }.padding(.all)
            }
        } detail: {
            if let configId = selectedConfig, let config = configs.first(where: { c in c.id == configId }) {
                SelectorView(config: config).padding(.all)
            } else {
                EmptyView()
            }
        }.navigationSplitViewStyle(.prominentDetail)
            .navigationSplitViewColumnWidth(ideal: idealSidebarWidth)
        /*NavigationView {
            VStack {
                List {
                    ForEach(configs) { config in
                        NavigationLink(destination: SelectorView(config: config).padding(.all)) {
                            Text(config.name ?? "Config \(config.index)")
                        }
                    }
                }
                HStack {
                    Button(action: addConfig) {
                        Image(nsImage: NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")!)
                    }
                    Spacer()
                }.padding(.all)
            }
        }*/
    }
    
    var idealSidebarWidth: CGFloat {
        get {
            let longestName = configs
                .map { c in c.name ?? "" }
                .map { s in NSAttributedString(string: s).boundingRect(with: NSSize(width: 1000, height: 1000)).width }
                .max() ?? 0
            return min(200.0, CGFloat(longestName))
        }
    }
    
    func addConfig() {
        var configs: [Config] = []
        for c in self.configs {
            configs.append(c)
        }
        let config = Config(context: viewContext)
        config.id = UUID()
        config.index = (configs.map { c in c.index }.max()?.inc() ?? 0)
        config.resultType = ResultType.String.tag()
        var name = "New Config"
        var i = 0
        while (configs.first(where: { c in c.name == name }) != nil) {
            i += 1
            name = "New Config \(i)"
        }
        config.name = name
        config.triggerInterval = 1
        config.triggerIntervalUnits = TimeUnit.Hours.tag()
        do {
            try viewContext.save()
        } catch {
            logger.error("error saving: \(error)")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
