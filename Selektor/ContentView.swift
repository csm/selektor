//
//  ContentView.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI
import RealmSwift

struct ContentView: View {
    @Environment(\.realm) private var realm

    @ObservedResults(ConfigV2.self, sortDescriptor: SortDescriptor(keyPath: \ConfigV2.index, ascending: true))
    private var configs
    @State var selectedConfig: ConfigV2.ID? = nil
    
    @State var showSubscriptionView: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(configs) { config in
                    NavigationLink(
                        destination: SelectorView(config: config)
                            .environment(\.realm, try! PersistenceV2.shared.realm)
                    ) {
                        HStack(alignment: .top) {
                            Text(config.name)
                            Spacer()
                            Text(config.lastValue?.formatted() ?? "").foregroundColor(.gray)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)
            }
            //.navigationDestination(for: Config.self) { config in
            //    SelectorView(config: config)
            //}
            .listStyle(.grouped)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("New", systemImage: "plus")
                    }
                }
            }
#if DEBUG
            List {
                NavigationLink("Debug Logs", value: true)
            }.navigationDestination(for: Bool.self) { _ in LogsView() }
#endif
            Text("Selektor").onTapGesture {
                showSubscriptionView = true
            }
        }.sheet(isPresented: $showSubscriptionView, onDismiss: { showSubscriptionView = false}) {
            SubscribeView().padding(.all)
        }
    }

    private func addItem() {
        do {
            try realm.write {
                let nextIndex = (configs.map { c in c.index }.max()?.inc() ?? 0)
                var name = "New Config"
                var i = 1
                while configs.first(where: { c in c.name == name }) != nil {
                    i += 1
                    name = "New Config \(i)"
                }
                let newItem = ConfigV2(index: nextIndex, name: name)
                newItem.triggerInterval = TimeDuration(value: 1, units: .Days)
                realm.add(newItem)
                selectedConfig = newItem.id
            }
        } catch {
            logger.error("failed to add config \(error)")
        }
    }
    
    private func moveItems(_ from: IndexSet, _ to: Int) {
        logger.debug("moveItems from: \(from) to: \(to)")
    }

    private func deleteItems(offsets: IndexSet) {
        logger.debug("deleteItems offsets: \(offsets)")
        /*withAnimation {
        }*/
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
