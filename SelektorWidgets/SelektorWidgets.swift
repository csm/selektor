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
        SimpleEntry(date: Date(), text: "--", label: "Selektor", configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        do {
            let e = try getEntry(context, configuration)
            completion(e)
        } catch {
            print("failed to get snapshot: \(error)")
            completion(placeholder(in: context))
        }
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        do {
            let entry = try getEntry(context, configuration)
            entries.append(entry)
        } catch {
            print("failed to get timeline: \(error)")
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func getEntry(_ context: Context, _ configuration: ConfigurationIntent) throws -> SimpleEntry {
        let request = NSFetchRequest<Config>(entityName: "Config")
        request.predicate = NSPredicate(format: "isWidget == TRUE")
        let entries = try managedObjectContext.fetch(request)
        print("got entries \(entries) with isWidget == TRUE")
        if let e = entries.first {
            print("returning entry lastFetch: \(e.lastFetch), result: \(e.result), name: \(e.name)")
            return SimpleEntry(date: e.lastFetch ?? Date(), text: e.result?.description() ?? "--", label: e.name ?? "", configuration: configuration)
        }
        return placeholder(in: context)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let text: String
    let label: String
    let configuration: ConfigurationIntent
}

struct SelektorWidgetsEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text(entry.label).font(.system(size: 12, weight: .black).lowercaseSmallCaps())
            Spacer()
            Text(entry.text)
            Spacer()
        }
    }
}

@main
struct SelektorWidgets: Widget {
    let kind: String = "SelektorWidgets"
    let config: Config? = getWidgetConfig()

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider(context: PersistenceController.shared.container.viewContext)) { entry in
            SelektorWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName(config?.name ?? "Selektor Widget")
        .description("Widget showing selected values from a web page.")
    }

    static func getWidgetConfig() -> Config? {
        do {
            let request = NSFetchRequest<Config>(entityName: "Config")
            request.predicate = NSPredicate(format: "isWidget == TRUE")
            let configs = try PersistenceController.shared.container.viewContext.fetch(request)
            return configs.first
        } catch {
            print("could not fetch configs: \(error)")
            return nil
        }
    }
}

struct SelektorWidgets_Previews: PreviewProvider {
    static var previews: some View {
        SelektorWidgetsEntryView(entry: SimpleEntry(date: Date(), text: "Test", label: "Preview", configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
