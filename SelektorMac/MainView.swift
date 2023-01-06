//
//  MainView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/2/23.
//

import SwiftUI
import ServiceManagement

struct MainView: View {
    @AppStorage("login-item-initialized")
    private var loginItemInitialized: Bool?
    
    var body: some View {
        VStack {
            Text("Selektor runs in the background on macOS as a Login Item, and provides a menu item helper for configuration and control. Click Allow to allow Selektor to ")
            HStack {
                Button("Quit") {
                    exit(0)
                }
                Spacer()
                Button("Allow") {
                    try? SMAppService.mainApp.register()
                    loginItemInitialized = true
                }
            }
        }.frame(width: 300, height: 225)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
