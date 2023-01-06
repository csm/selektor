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
    
    var body: some View {
        NavigationView {
            List {
                ForEach(configs) { config in
                    NavigationLink(destination: SelectorView(config: config).padding(.all)) {
                        Text(config.name ?? "Config \(config.index)")
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
