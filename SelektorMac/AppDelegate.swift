//
//  AppDelegate.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/2/23.
//

import AppKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    
    @IBOutlet weak var menu: NSMenu?
    @IBOutlet weak var firstItem: NSMenuItem?
    
    var displayedConfigs: [Config] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Scheduler.shared.scheduleConfigs()
    }
    
    override func awakeFromNib() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Selektor"
        statusItem?.button?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        statusItem?.menu = menu
    }
    
    @objc func menuNeedsUpdate(_ menu: NSMenu) {
        logger.debug("menuNeedsUpdate \(menu) \(menu == self.menu)")
        if menu == self.menu {
            let viewContext = PersistenceController.shared.container.viewContext
            let fetchRequest = NSFetchRequest<Config>(entityName: "Config")
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Config.index, ascending: true)]
            fetchRequest.fetchLimit = 15
            let menuItems = menu.items
            let keepItems = menuItems.drop { item in
                item != firstItem
            }
            for item in menuItems {
                menu.removeItem(item)
            }
            do {
                let results = try viewContext.fetch(fetchRequest)
                if results.isEmpty {
                    menu.insertItem(NSMenuItem(title: "No Items", action: nil, keyEquivalent: ""), at: 0)
                } else {
                    displayedConfigs = results
                    for (index, config) in results.enumerated() {
                        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                        switch index {
                        case 0:
                            item.target = self
                            item.action = #selector(configEntry0Clicked(_:))
                        case 1:
                            item.target = self
                            item.action = #selector(configEntry1Clicked(_:))
                        case 2:
                            item.target = self
                            item.action = #selector(configEntry2Clicked(_:))
                        case 3:
                            item.target = self
                            item.action = #selector(configEntry3Clicked(_:))
                        case 4:
                            item.target = self
                            item.action = #selector(configEntry4Clicked(_:))
                        case 5:
                            item.target = self
                            item.action = #selector(configEntry5Clicked(_:))
                        case 6:
                            item.target = self
                            item.action = #selector(configEntry6Clicked(_:))
                        case 7:
                            item.target = self
                            item.action = #selector(configEntry7Clicked(_:))
                        case 8:
                            item.target = self
                            item.action = #selector(configEntry8Clicked(_:))
                        case 9:
                            item.target = self
                            item.action = #selector(configEntry9Clicked(_:))
                        case 10:
                            item.target = self
                            item.action = #selector(configEntry10Clicked(_:))
                        case 11:
                            item.target = self
                            item.action = #selector(configEntry11Clicked(_:))
                        case 12:
                            item.target = self
                            item.action = #selector(configEntry12Clicked(_:))
                        case 13:
                            item.target = self
                            item.action = #selector(configEntry13Clicked(_:))
                        case 14:
                            item.target = self
                            item.action = #selector(configEntry14Clicked(_:))
                        default:
                            break
                        }
                        item.target = self
                        var style = NSMutableParagraphStyle()
                        let itemWidth: CGFloat = 300
                        style.tabStops = [
                            NSTextTab(textAlignment: .left, location: 0),
                            NSTextTab(textAlignment: .right, location: CGFloat(itemWidth))
                        ]
                        let attributes: [NSAttributedString.Key: Any] = [
                            .foregroundColor: NSColor.controlTextColor,
                            .paragraphStyle: style
                        ]
                        let attributes2: [NSAttributedString.Key: Any] = [
                            .foregroundColor: NSColor.gray,
                            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                        ]
                        let nameContent = wordWrap(config.name ?? "New Config", limit: 150, font: NSFont.systemFont(ofSize: NSFont.systemFontSize))
                        let resultContent = wordWrap(config.result?.description() ?? "", limit: 143, font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize))
                        let nameContentPadded = pad(array: nameContent, to: resultContent.count, with: "")
                        let resultContentPadded = pad(array: resultContent, to: nameContent.count, with: "")
                        let content = zip(nameContentPadded, resultContentPadded).map {
                            "\($0)\t\($1)"
                        }.joined(separator: "\r")
                        let attributeRanges = attributeRanges(for: nameContentPadded, and: resultContentPadded, leftAttributes: attributes, rightAttributes: attributes2)
                        //slet content = "\(config.name ?? "")\t\(config.result?.description() ?? "")\nThis is just\tSome test text"
                        var attributedString = NSMutableAttributedString(string: content)
                        attributedString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.count - 1))
                        for (attributes, range) in attributeRanges {
                            attributedString.addAttributes(attributes, range: range)
                        }
                        item.attributedTitle = attributedString
                        //let rootView = ConfigView(config: config).frame(minWidth: 300, minHeight: 14)
                        //item.view = NSHostingView(rootView: rootView)
                        //logger.debug("inserting menu item: \(item) \(rootView)")
                        menu.addItem(item)
                    }
                }
            } catch {
                logger.error("error fetching configs: \(error)")
            }
            keepItems.forEach(menu.addItem(_:))
        }
    }
    
    @IBAction
    @objc func openSettings(_ sender: Any?) {
        SettingsView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .openWindow(with: "Selektor", level: .modalPanel, size: CGSize(width: 640, height: 480))
    }
    
    func configEntryClicked(_ sender: Any?, index: Int) {
        if index < displayedConfigs.count {
            let config = displayedConfigs[index]
            if let id = config.id {
                HistoryView(id: id, name: config.name ?? "")
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                    .openWindow(with: "", level: .modalPanel, size: CGSize(width: 640, height: 480))
            }
        }
    }
    
    @objc func configEntry0Clicked(_ sender: Any?) { configEntryClicked(sender, index: 0) }
    @objc func configEntry1Clicked(_ sender: Any?) { configEntryClicked(sender, index: 1) }
    @objc func configEntry2Clicked(_ sender: Any?) { configEntryClicked(sender, index: 2) }
    @objc func configEntry3Clicked(_ sender: Any?) { configEntryClicked(sender, index: 3) }
    @objc func configEntry4Clicked(_ sender: Any?) { configEntryClicked(sender, index: 4) }
    @objc func configEntry5Clicked(_ sender: Any?) { configEntryClicked(sender, index: 5) }
    @objc func configEntry6Clicked(_ sender: Any?) { configEntryClicked(sender, index: 6) }
    @objc func configEntry7Clicked(_ sender: Any?) { configEntryClicked(sender, index: 7) }
    @objc func configEntry8Clicked(_ sender: Any?) { configEntryClicked(sender, index: 8) }
    @objc func configEntry9Clicked(_ sender: Any?) { configEntryClicked(sender, index: 9) }
    @objc func configEntry10Clicked(_ sender: Any?) { configEntryClicked(sender, index: 10) }
    @objc func configEntry11Clicked(_ sender: Any?) { configEntryClicked(sender, index: 11) }
    @objc func configEntry12Clicked(_ sender: Any?) { configEntryClicked(sender, index: 12) }
    @objc func configEntry13Clicked(_ sender: Any?) { configEntryClicked(sender, index: 13) }
    @objc func configEntry14Clicked(_ sender: Any?) { configEntryClicked(sender, index: 14) }

    /*
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
            statusButton.action = #selector(togglePopover(sender:))
            statusButton.target = self
        }
        
        popover = NSPopover()
        let fetchRequest = NSFetchRequest<Config>(entityName: "Config")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Config.index, ascending: true)]
        let results = (try? PersistenceController.shared.container.viewContext.fetch(fetchRequest)) ?? []
        let rootView = Menu("Selektor") {
            ForEach(results) { config in
                Text(config.name ?? "New Config")
            }
#if DEBUG
            Button("Debug Logs") {
                logger.info("TODO")
            }
#endif
            Button("Settings") {}
            Button("Quit") {}
        }
        /*
         let rootView = PopoverView()
         .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
         .frame(minWidth: 320)
         .padding(.all)
         */
//        let content = NSHostingController(rootView: rootView)
        let menu = NSMenu()
        let menuItem = NSMenuItem()
        menuItem.view = NSHostingView(rootView: rootView)
        menu.addItem(menuItem)
        statusItem.menu = menu
        
//        popover.contentViewController = content
//        popover.contentSize = content.view.intrinsicContentSize
//        popover.behavior = .transient
    }
    */
}
