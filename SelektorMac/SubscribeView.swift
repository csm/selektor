//
//  SubscriptionView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/23/23.
//

import SwiftUI
import StoreKit

struct SubscribeView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    let dateFormatter: DateFormatter
    @State var purchasing: Product? = nil
    
    init() {
        self.subscriptionManager = SubscriptionManager.shared
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateStyle = .short
    }
    
    var body: some View {
        HStack {
            switch subscriptionManager.subscriptionState {
            
            case .subscribed(let until):
                VStack {
                    Text("You're subscribed!")
                    Spacer()
                    if let until = until {
                        Text("You have full access to Selektor until \(dateFormatter.string(from: until)).").lineLimit(nil)
                    } else {
                        Text("You have full access to Selektor.").lineLimit(nil)
                    }
                    Spacer()
                    Text("Thanks for your support!")
                }.padding(.all)
            
            case .unknown, .loading:
                VStack {
                    Text("Reading subscription status...")
                    Spacer().frame(maxHeight: 20)
                    ProgressView()
                }.padding(.all)
            
            default:
                VStack {
                    Text("Subscribe to Selektor").font(.title)
                    switch subscriptionManager.productState {
                    case .unknown, .loading:
                        VStack {
                            Text("Loading Products")
                            ProgressView()
                        }
                    case .error(let cause):
                        VStack {
                            Text("Could not load subscriptions:")
                            Text("\(cause.localizedDescription)")
                        }
                    case .loaded:
                        ForEach(subscriptionManager.products) { product in
                            HStack {
                                Spacer()
                                Text("\(product.displayName)")
                                Button("\(product.displayPrice)") {
                                    purchasing = product
                                    Task() {
                                        await subscriptionManager.purchase(product)
                                        self.purchasing = nil
                                    }
                                }.disabled(purchasing != nil)
                            }
                        }
                    }
                }
            }
        }.onAppear {
            Task() {
                await subscriptionManager.loadData()
            }
        }
    }
    
    func purchase(product: Product) async {
        do {
            let result = try await product.purchase(options: [
                .appAccountToken(subscriptionManager.appAccountId)
            ])
            await subscriptionManager.loadData()
        } catch {
            logger.error("error purchasing: \(error)")
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    init() {
        SubscriptionManager.shared.subscriptionState = .subscribed(until: Date())
    }
    static var previews: some View {
        SubscribeView()
    }
}
