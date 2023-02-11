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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.realm, try! PersistenceV2.shared.realm)
        }
    }
}
