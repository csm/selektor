//
//  HistoryView.swift
//  Selektor
//
//  Created by Casey Marshall on 12/5/22.
//

import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let id: UUID
    @State var history: [History] = []
    
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        List {
            ForEach(history) { e in
                VStack {
                    Text("\(e.date ?? Date(), formatter: HistoryView.dateFormatter)")
                        .font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                    if let err = e.error {
                        Text(err).foregroundColor(.red)
                    } else {
                        Text(e.result?.description() ?? "")
                    }
                }
            }
        }.onAppear {
            let request = NSFetchRequest<History>(entityName: "History")
            request.predicate = NSPredicate(format: "configId == %@", argumentArray: [id])
            request.sortDescriptors = [NSSortDescriptor(keyPath: \History.date, ascending: false)]
            do {
                history = try viewContext.fetch(request).filter { e in e.date != nil }
                print("fetched history: \(history)")
            } catch {
                print("could not fetch history! \(error)")
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(id: UUID())
    }
}
