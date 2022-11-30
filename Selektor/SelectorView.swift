//
//  SelectorView.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI
import CoreData

struct SelectorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State var config: Config

    var body: some View {
        NavigationView {
            List {
                TextField("Name", text: Binding($config.name, replacingNilWith: ""))
                TextField("URL", text: urlStringBinding(source: $config.url))
                HStack {
                    TextField("Frequency", text: int64StringBinding(source: $config.triggerInterval))
                    /*Picker("", selection: stringTimeUnitBinding(source: $config.triggerIntervalUnits)) {
                        Text("Seconds").tag(TimeUnit.Seconds)
                        Text("Minutes").tag(TimeUnit.Minutes)
                        Text("Hours").tag(TimeUnit.Hours)
                    }*/
                }
            }.listStyle(.grouped)
        }
    }
}

struct SelectorView_Previews: PreviewProvider {
    static var previews: some View {
        SelectorView(config: createConfig()).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
    
    static func createConfig() -> Config {
        let config = Config(context: PersistenceController.preview.container.viewContext)
        config.name = "Config Name"
        config.url = URL(string: "http://localhost")
        config.triggerInterval = 0
        config.triggerIntervalUnits = "s"
        return config
    }
}
