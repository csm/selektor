//
//  SubscribeView.swift
//  Selektor
//
//  Created by Casey Marshall on 12/22/22.
//

import SwiftUI
import StoreKit

struct SubscribeView: View {
    enum ViewState {
        case loadingInfo
        case needsSubscription
        case subscribed
    }
    
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State var state: ViewState = .loadingInfo
    let formatter: DateFormatter = {
        let d = DateFormatter()
        d.dateStyle = .medium
        return d
    }()
    
    var body: some View {
        switch subscriptionManager.subscriptionState {
        case .unknown, .loading:
            VStack {
                Text("Loading subscriptions...")
                ProgressView()
                Spacer()
            }
        case .notSubscribed:
            switch subscriptionManager.productState {
            case .unknown, .loading:
                VStack {
                    Text("Loading subscriptions...")
                    ProgressView()
                    Spacer()
                }
            case .loaded:
                VStack {
                    Text("Subscribe to Selektor").font(.title)
                    Spacer()
                    Text("Subscribe to access the full app: schedule selectors and configure alerts.").lineLimit(nil).multilineTextAlignment(.center).padding(.bottom, 20)
                    ForEach(subscriptionManager.products) { product in
                        VStack {
                            Text("\(product.displayName)")
                            Button("\(product.displayPrice)") {
                                Task() {
                                    await subscriptionManager.purchase(product)
                                }
                            }.font(.headline).buttonStyle(.borderedProminent).padding(.bottom, 10)
                        }
                    }
                    Spacer()
                }
            case .error(let cause):
                VStack {
                    Text("Could not load products.")
                    Text("\(cause.localizedDescription)")
                }
            }
        case .subscribed(let until):
            VStack {
                Text("You're Subscribed!").font(.title)
                if let until = until {
                    Text("You have full access to Selektor until \(formatter.string(from: until))").lineLimit(nil)
                } else {
                    Text("You have full access to Selektor.")
                }
                Text("Thanks for your support!")
            }
        }
    }
}

struct SubscribeView_Previews: PreviewProvider {
    static var previews: some View {
        SubscribeView()
    }
}
