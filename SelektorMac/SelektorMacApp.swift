//
//  SelektorMacApp.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/2/23.
//

import SwiftUI

@main
struct SelektorMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    
    @AppStorage("login-item-initialized")
    private var loginItemInitialized: Bool?

    var body: some Scene {
        WindowGroup {
            if loginItemInitialized != true {
                MainView()
            }
        }
    }
}
