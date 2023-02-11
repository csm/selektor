//
//  HistoryView.swift
//  Selektor
//
//  Created by Casey Marshall on 12/5/22.
//

import RealmSwift
import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.realm) private var realm

    let id: ObjectId
    let name: String
    @State var history: [HistoryV2] = []
    
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
    
    let dateFont = Font.headline
    
    var body: some View {
        Text(name).font(.title2)
        List {
            ForEach(history) { e in
                HStack(alignment: .center) {
                    Text("\(e.date , formatter: HistoryView.dateFormatter)")
                        .font(dateFont)
                    Spacer()
                    if let err = e.error {
                        Text(err).foregroundColor(.red)
                    } else {
                        Text(e.result?.formatted() ?? "")
                    }
                }
            }
        }.onAppear {
            history = realm.objects(HistoryV2.self).where { h in h.configId == id }.sorted(by: { (a, b) in a.date > b.date })
            logger.info("loaded history: \(history)")
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(id: ObjectId(), name: "Example")
    }
}
