//
//  SelektorApp.swift
//  Selektor
//
//  Created by Casey Marshall on 11/29/22.
//

import SwiftUI

@main
struct SelektorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
