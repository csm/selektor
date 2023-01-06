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
    
    @State var state: ViewState = .loadingInfo
    
    var body: some View {
        switch (state) {
        case .loadingInfo:
            VStack(alignment: .center) {
                Text("Loading Subscription")
            }.onAppear {
                
            }
        case .needsSubscription:
            VStack(alignment: .center) {
                Text("Please subscribe to Selektor!")
            }
        case .subscribed:
            VStack(alignment: .center) {
                Text("You're subscribed!")
            }
        }
    }
    
    func loadTransactions() async {
        for await verificationResult in Transaction.currentEntitlements {
            switch verificationResult {
            case .verified(let transaction):
                // TODO verify subscription
                state = .subscribed
            case .unverified(_, let verificationError):
                logger.warning("transaction unverified with error: \(verificationError)")
            }
        }
        if state == .loadingInfo {
            state = .needsSubscription
        }
    }
}

struct SubscribeView_Previews: PreviewProvider {
    static var previews: some View {
        SubscribeView()
    }
}
