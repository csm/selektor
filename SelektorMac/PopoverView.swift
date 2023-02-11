//
//  PopoverView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/3/23.
//

import SwiftUI

struct PopoverView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    enum HoveredElement {
        case none
        case debugLogs
        case settings
        case quit
        case config(config: Config)
    }
    
    @State var hoveredElement: HoveredElement = .none

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Config.index, ascending: true)],
        animation: .default)
    private var configs: FetchedResults<Config>
    
    var body: some View {
        /*
        Menu("Selektor") {
            ForEach(configs) { config in
                Text(config.name ?? "New Config")
            }
#if DEBUG
            Button("Debug Logs") {
                LogsView()
                    .openWindow(with: "Debug Logs", level: .floating, size: CGSize(width: 640, height: 480))
            }
#endif
            Button("Settings") {
                SettingsView()
                    .environment(\.managedObjectContext, viewContext)
                    .openWindow(with: "Selektor", level: .floating, size: CGSize(width: 720, height: 680))
            }
            
            Button("Quit") {
                exit(0)
            }
        }*/
        VStack {
            Text("Selektor").font(.system(size: 16, weight: .bold))
            ForEach(configs) { config in
                VStack {
                    HStack(alignment: .top) {
                        Text(config.name ?? "New Config")
                        Spacer()
                        Text(config.lastValue?.formatted() ?? "")
                            .lineLimit(nil)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.gray)
                    }
                }.padding(.bottom, 4)
                    .background(configBackgroundColor(config))
                    .onTapGesture {
                        HistoryView(id: config.id, name: config.name!).environment(\.managedObjectContext, viewContext).openWindow(size: CGSize(width: 480, height: 640))
                    }.onHover { hover in
                        if hover {
                            hoveredElement = .config(config: config)
                        } else if case let HoveredElement.config(e) = hoveredElement, e.id == config.id {
                            hoveredElement = .none
                        }
                    }
            }
            Divider()
#if DEBUG
            VStack(alignment: .leading) {
                Text("Debug Logs")
                Divider(color: .clear)
            }.onTapGesture {
                LogsView()
                    .openWindow(with: "Debug Logs", level: .floating, size: CGSize(width: 640, height: 480))
            }.onHover { hover in
                if hover {
                    hoveredElement = .debugLogs
                } else if case .debugLogs = hoveredElement {
                    hoveredElement = .none
                }
            }.background(debugLogsBackgroundColor())
#endif
            VStack(alignment: .leading) {
                Text("Settings")
                Divider(color: .clear)
            }.onTapGesture {
                SettingsView()
                    .environment(\.managedObjectContext, viewContext)
                    .openWindow(with: "Selektor", level: .floating, size: CGSize(width: 720, height: 680))
            }.onHover { hover in
                if hover {
                    hoveredElement = .settings
                } else if case .settings = hoveredElement {
                    hoveredElement = .none
                }
            }.background(settingsBackgroundColor())
            VStack(alignment: .leading) {
                HStack {
                    Text("Quit")
                    Spacer()
                }
            }.onTapGesture {
                exit(0)
            }.onHover { hover in
                if hover {
                    hoveredElement = .quit
                } else if case .quit = hoveredElement {
                    hoveredElement = .none
                }
            }.background(quitBackgroundColor())
        }
    }
    
    func configBackgroundColor(_ config: Config) -> Color {
        switch hoveredElement {
        case let .config(c) where c.id == config.id:
                return .blue
        default: return .clear
        }
    }
    
    func debugLogsBackgroundColor() -> Color {
        if case .debugLogs = hoveredElement {
            return .blue
        }
        return .clear
    }
    
    func settingsBackgroundColor() -> Color {
        if case .settings = hoveredElement {
            return .blue
        }
        return .clear
    }
    
    func quitBackgroundColor() -> Color {
        if case .quit = hoveredElement {
            return .blue
        }
        return .clear
    }
}

struct PopoverView_Previews: PreviewProvider {
    static var previews: some View {
        PopoverView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
