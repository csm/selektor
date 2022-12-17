//
//  SelektorWidgets.swift
//  SelektorWidgets
//
//  Created by Casey Marshall on 12/2/22.
//

import WidgetKit
import SwiftUI
import Intents
import CoreData

struct Provider: IntentTimelineProvider {
    var managedObjectContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), results: [ResultEntry(date: Date(), text: "--", label: "Selektor")], configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        do {
            let e = try getEntry(context, configuration)
            completion(e)
        } catch {
            logger.error("failed to get snapshot: \(error)")
            completion(placeholder(in: context))
        }
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        do {
            entries = try getEntries(context, configuration)
        } catch {
            logger.error("failed to get timeline: \(error)")
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func getEntry(_ context: Context, _ configuration: ConfigurationIntent) throws -> SimpleEntry {
        logger.notice("fetching entry...")
        let request = NSFetchRequest<Config>(entityName: "Config")
        request.predicate = NSPredicate(format: "isWidget == TRUE")
        let entries = try managedObjectContext.fetch(request)
        logger.notice("got entries \(entries) with isWidget == TRUE")
        if !entries.isEmpty {
            return SimpleEntry(
                date: Date(),
                results: entries.map { entry in
                    ResultEntry(date: entry.lastFetch ?? Date(), text: entry.result?.description() ?? "--", label: entry.name ?? "")
                },
                configuration: configuration
            )
        }
        return placeholder(in: context)
    }
    
    private func getEntries(_ context: Context, _ configuration: ConfigurationIntent) throws -> [SimpleEntry] {
        logger.notice("fetching entries...")
        let configRequest = NSFetchRequest<Config>(entityName: "Config")
        configRequest.predicate = NSPredicate(format: "isWidget == TRUE")
        let entries = try managedObjectContext.fetch(configRequest)
        if let config = entries.first, let id = config.id {
            let request = NSFetchRequest<History>(entityName: "History")
            request.predicate = NSPredicate(format: "configId == %@", argumentArray: [id])
            request.sortDescriptors = [NSSortDescriptor(keyPath: \History.date, ascending: false)]
            let history = try managedObjectContext.fetch(request)
            var results: [SimpleEntry] = []
            history.forEach { entry in
                results.append(SimpleEntry(date: entry.date!, results: [ResultEntry(date: entry.date!, text: entry.result?.description() ?? "", label: config.name ?? "Selektor")], configuration: configuration))
            }
            return results
        }
        return []
    }
}

struct ResultEntry: Identifiable {
    let date: Date
    let text: String
    let label: String
    let id: String
    
    init(date: Date, text: String, label: String, id: String = UUID().uuidString) {
        self.date = date
        self.text = text
        self.label = label
        self.id = id
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let results: [ResultEntry]
    let configuration: ConfigurationIntent
}

let dateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    return f
}()

struct SelektorWidgetsEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        //TabView() {
            VStack {
                ForEach(entry.results) { result in
                    VStack {
                        Spacer()
                        Text(result.label).font(.system(size: 12, weight: .black).lowercaseSmallCaps())
                        Spacer()
                        Text(result.text).font(.system(size: 24))
                        Spacer()
                        Text("\(result.date, formatter: dateFormatter)")
                        Spacer()
                    }
                }
            }
        //}.tabViewStyle(.page)
    }
}

@main
struct SelektorWidgets: Widget {
    let kind: String = "SelektorWidgets"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider(context: PersistenceController.shared.container.viewContext)) { entry in
            SelektorWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Selektor")
        .description("Widget showing selected values from a web page.")
    }
}

struct SelektorWidgets_Previews: PreviewProvider {
    static var previews: some View {
        SelektorWidgetsEntryView(entry: SimpleEntry(date: Date(), results: [ResultEntry(date: Date(), text: "Test", label: "Preview")], configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
