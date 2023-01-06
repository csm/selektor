//
//  ContentView.swift
//  SelektorWatchApp Watch App
//
//  Created by Casey Marshall on 12/19/22.
//

import SwiftUI

struct ResultLite {
    let configId: String
    let name: String
    let resultValue: String
    let lastFetch: Date
}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
