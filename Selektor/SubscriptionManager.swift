//
//  SubscriptionManager.swift
//  Selektor
//
//  Created by Casey Marshall on 12/22/22.
//

import Foundation
import StoreKit

enum SubscriptionState {
    case unknown
    case loading
    case subscribed(until: Date?)
    case notSubscribed
}

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var subscriptionState: SubscriptionState = .unknown

    func loadSubscriptions() async {
        subscriptionState = .loading
        for await verificationResult in Transaction.currentEntitlements {
            switch verificationResult {
            case .verified(let transaction):
                subscriptionState = .subscribed(until: transaction.expirationDate)
            case .unverified(_, let error):
                logger.info("transaction unverified error: \(error)")
            }
        }
        switch subscriptionState {
        case .loading, .unknown:
            subscriptionState = .notSubscribed
        default:
            break
        }
    }
}
