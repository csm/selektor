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

    var body: some View {
        NavigationView {
            List {
                ForEach(configs) { config in
                    NavigationLink {
                        SelectorView(config: config).environment(\.managedObjectContext, viewContext)
                    } label: {
                        Text(config.name ?? "")
                    }
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)
            }
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
            Text("Select an item")
        }
    }

    private func addItem() {
        let newItem = Config(context: viewContext)
        newItem.index = (configs.map(\.index).max() ?? 0) + 1
        newItem.name = "New Config"
        var i = 1
        while configs.first(where: { c in c.name == newItem.name }) != nil {
            i += 1
            newItem.name = "New Config \(i)"
        }
        NavigationLink(destination: SelectorView(config: newItem)) { EmptyView() }
            
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
        print("TODO: handle moveItems from: \(from) to: \(to)")
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
