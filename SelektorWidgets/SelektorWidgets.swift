//
//  SelektorWidgets.swift
//  SelektorWidgets
//
//  Created by Casey Marshall on 12/2/22.
//

import WidgetKit
import SwiftUI
import Intents
import RealmSwift

@main
struct SelektorWidgets: WidgetBundle {
    init() {
    }
    
    @WidgetBundleBuilder
    var body: some Widget {
        SelektorWidget(0)
        SelektorWidget(1)
        SelektorWidget(2)
        SelektorWidget(3)
    }
}

struct Provider: IntentTimelineProvider {
    let configIndex: Int

    init(configIndex: Int) {
        self.configIndex = configIndex
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
        let realm = try PersistenceV2.readOnly.realm
        let entries = realm.objects(ConfigV2.self).where { c in c.isWidget }
        logger.notice("got entries \(entries) with isWidget == TRUE")
        if let config = entries.dropFirst(configIndex).first {
            return SimpleEntry(
                date: config.lastFetch ?? Date(),
                results: [ResultEntry(date: config.lastFetch ?? Date(), text: config.lastValue?.formatted() ?? "--", label: config.name)],
                configuration: configuration
            )
        }
        return placeholder(in: context)
    }
    
    private func getEntries(_ context: Context, _ configuration: ConfigurationIntent) throws -> [SimpleEntry] {
        logger.notice("fetching entries...")
        let realm = try PersistenceV2.readOnly.realm
        let entries = realm.objects(ConfigV2.self).where { c in c.isWidget }.sorted(by: { (a, b) in a.index < b.index })
        if let config = entries.dropFirst(configIndex).first {
            let id = config.id
            let history = realm.objects(HistoryV2.self).where { h in h.configId == id }.sorted(by: { (a, b) in a.date < b.date })
            var results: [SimpleEntry] = []
            history.forEach { entry in
                results.append(SimpleEntry(date: entry.date, results: [ResultEntry(date: entry.date, text: entry.result?.formatted() ?? "", label: config.name)], configuration: configuration))
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

    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack {
            switch family {
            case .accessoryInline, .accessoryCircular, .accessoryRectangular:
                if let r = entry.results.first {
                    VStack(alignment: .center) {
                        Spacer()
                        Text(r.label).minimumScaleFactor(0.1)
                        Spacer()
                        Text(r.text)
                        Spacer()
                    }
                } else {
                    Text("--")
                }
            default:
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
        }
    }
}

struct SelektorWidget: Widget {
    let kind: String = "SelektorWidgets"
    let configIndex: Int

    init() {
        self.configIndex = 0
    }
    
    init(_ configIndex: Int) {
        self.configIndex = configIndex
    }
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider(configIndex: configIndex)) { entry in
            SelektorWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Selektor")
        .description("Widget showing selected values from a web page.")
#if os(iOS)
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ])
#else
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
        ])
#endif
    }
}

struct SelektorWidgets_Previews: PreviewProvider {
    static var previews: some View {
        SelektorWidgetsEntryView(entry: SimpleEntry(date: Date(), results: [ResultEntry(date: Date(), text: "Test", label: "Preview")], configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
