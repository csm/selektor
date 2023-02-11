//
//  SettingsView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/3/23.
//

import RealmSwift
import SwiftUI

struct SettingsView: View {
    @Environment(\.realm) private var realm
    
    @ObservedResults(ConfigV2.self, sortDescriptor: SortDescriptor(keyPath: \ConfigV2.index, ascending: true)) var configs
    @State var selectedConfig: ConfigV2.ID? = nil
    
    var selectedConfigObject: ConfigV2? {
        get {
            return configs.first(where: {c in c.id == selectedConfig })
        }
    }
    
    var selectedConfigIsFirst: Bool {
        get {
            let minIndex = configs.map({c in c.index}).min() ?? 0
            return selectedConfig != nil && configs.first(where: {c in c.id == selectedConfig})?.index == minIndex
        }
    }
    
    var selectedConfigIsLast: Bool {
        get {
            let maxIndex = configs.map({c in c.index}).max() ?? 0
            return selectedConfig != nil && configs.first(where: {c in c.id == selectedConfig})?.index == maxIndex
        }
    }
    
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
                    Button(action: moveConfigUp) {
                        Image(nsImage: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Move Up")!)
                    }.disabled(
                        selectedConfig == nil || selectedConfigIsFirst
                    )
                    Button(action: moveConfigDown) {
                        Image(nsImage: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Move Down")!)
                    }.disabled(
                        selectedConfig == nil || selectedConfigIsLast
                    )
                    Button(action: deleteConfig) {
                        Image(nsImage: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")!)
                    }.disabled(selectedConfig == nil)
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
        do {
            try realm.write {
                let nextIndex = (configs.map { c in c.index }.max()?.inc() ?? 0)
                var name = "New Config"
                var i = 1
                while (configs.first(where: { c in c.name == name }) != nil) {
                    i += 1
                    name = "New Config \(i)"
                }
                let config = ConfigV2(index: nextIndex, name: name)
                config.triggerInterval = TimeDuration(value: 1, units: .Days)
                realm.add(config)
                selectedConfig = config.id
            }
        } catch {
            logger.error("error saving: \(error)")
        }
    }
    
    func moveConfigUp() {
        do {
            if let currentConfig = configs.first(where: {c in c.id == selectedConfig}) {
                if let prevConfig = configs.filter({c in c.index < currentConfig.index}).max(by: {(a, b) in a.index < b.index}) {
                    do {
                        try realm.write {
                            let t = prevConfig.index
                            prevConfig.index = currentConfig.index
                            currentConfig.index = t
                        }
                    } catch {
                        logger.error("could not save configs: \(error)")
                    }
                } else {
                    logger.debug("no prev config")
                }
            } else {
                logger.debug("no current config \(selectedConfig)")
            }
        } catch {
            logger.error("could not save moving up: \(error)")
        }
    }
    
    func moveConfigDown() {
        do {
            if let currentConfig = configs.first(where: {c in c.id == selectedConfig}) {
                if let nextConfig = configs.filter({c in c.index > currentConfig.index}).min(by: {(a, b) in a.index < b.index}) {
                    do {
                        try realm.write {
                            let t = nextConfig.index
                            nextConfig.index = currentConfig.index
                            currentConfig.index = t
                        }
                    } catch {
                        logger.error("could not save configs: \(error)")
                    }
                } else {
                    logger.debug("no next config")
                }
            } else {
                logger.debug("no current config \(selectedConfig)")
            }
        } catch {
            logger.error("could not save moving down: \(error)")
        }
    }
    
    func deleteConfig() {
        if let currentConfig = realm.object(ofType: ConfigV2.self, forPrimaryKey: selectedConfig) {
            do {
                try PersistenceV2.shared.deleteConfig(realm: realm, config: currentConfig)
            } catch {
                logger.error("could not delete config: \(error)")
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environment(\.realm, try! PersistenceV2.preview.realm)
    }
}
