//
//  ContentView.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Config.index, ascending: true)],
        animation: .default)
    private var configs: FetchedResults<Config>
    @State var showSubscriptionView: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(configs) { config in
                    NavigationLink(destination: SelectorView(config: config)) {
                        HStack {
                            Text(config.name ?? "")
                            Spacer()
                            Text(config.result?.description() ?? "").foregroundColor(.gray)
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
        let newItem = Config(context: viewContext)
        newItem.index = (configs.map(\.index).max() ?? -1) + 1
        newItem.name = "New Config"
        newItem.id = UUID()
        newItem.triggerInterval = 1
        newItem.triggerIntervalUnits = TimeUnit.Hours.tag()
        newItem.resultTypeValue = .String
        var i = 1
        while configs.first(where: { c in c.name == newItem.name }) != nil {
            i += 1
            newItem.name = "New Config \(i)"
        }

            /*do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }*/
    }
    
    private func moveItems(_ from: IndexSet, _ to: Int) {
        let fromIndex = from.first!
        configs.forEach { config in
            if (config.index == fromIndex) {
                config.index = Int32(to)
            } else if (config.index >= to) {
                config.index += 1
            }
        }
        do {
            try viewContext.save()
        } catch {
            logger.error("error saving \(error)")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { configs[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
