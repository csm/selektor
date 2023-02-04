//
//  SubscriptionManager.swift
//  Selektor
//
//  Created by Casey Marshall on 12/22/22.
//

import Foundation
import StoreKit

enum ProductState {
    case unknown
    case loading
    case loaded
    case error(cause: Error)
}

enum SubscriptionState {
    case unknown
    case loading
    case subscribed(until: Date?)
    case notSubscribed
}

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    static let productIds = [
        "org.metastatic.selektor.subscription.yearly",
        "org.metastatic.selektor.subscription.monthly"
    ]
    
    @Published var productState: ProductState = .unknown
    @Published var subscriptionState: SubscriptionState = .unknown
    @Published var products: [Product] = []
    
    private var updatesTask: Task<Void, Never>? = nil
    
    init() {
        updatesTask = transactionListenerTask()
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    func transactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await verificationResult in Transaction.updates {
                await handleVerificationResult(verificationResult)
            }
        }
    }
    
    var appAccountId: UUID {
        get {
            if let s = UserDefaults.standard.string(forKey: "app-account-id"), let accountId = UUID(uuidString: s) {
                return accountId
            }
            let id = UUID()
            UserDefaults.standard.set(id.uuidString, forKey: "app-account-id")
            return id
        }
    }
    
    var isSubscribed: Bool {
        get {
            if case .subscribed(let until) = subscriptionState {
                if let until = until {
                    return until > Date()
                }
                return true
            }
            return false
        }
    }
    
    private func handleVerificationResult(_ verificationResult: VerificationResult<Transaction>) async {
        logger.debug("verification result: \(verificationResult) -- \(verificationResult.jwsRepresentation)")
        switch verificationResult {
        case .unverified(_, _):
            logger.info("ignoring unverified transaction")
            return
        case .verified(let transaction):
            if let revocationDate = transaction.revocationDate {
                if revocationDate <= Date() {
                    await update(subscriptionState: .notSubscribed)
                }
            } else if let expirationDate = transaction.expirationDate {
                if expirationDate <= Date() {
                    await update(subscriptionState: .notSubscribed)
                } else {
                    await update(subscriptionState: .subscribed(until: expirationDate))
                }
            } else {
                await update(subscriptionState: .subscribed(until: nil))
            }
        }
    }
    
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase(options: [
                .appAccountToken(appAccountId)
            ])
            logger.info("purchase result: \(result)")
            if case .success(let verificationResult) = result {
                await handleVerificationResult(verificationResult)
            }
        } catch {
            logger.error("error purchasing: \(error)")
        }
    }
    
    func currentEntitlementJws() async -> String? {
        for await verificationResult in Transaction.currentEntitlements {
            if case .verified(_) = verificationResult {
                return verificationResult.jwsRepresentation
            }
        }
        return nil
    }
    
    func loadData() async {
        await loadProducts()
        await loadSubscriptions()
    }

    func loadSubscriptions() async {
        await update(subscriptionState: .loading)
        for await verificationResult in Transaction.currentEntitlements {
            await handleVerificationResult(verificationResult)
        }
        switch subscriptionState {
        case .loading, .unknown:
            await update(subscriptionState: .notSubscribed)
        default:
            break
        }
    }
    
    func loadProducts() async {
        await update(productState: .loading)
        do {
            let products = try await Product.products(for: SubscriptionManager.productIds)
            logger.info("loaded products: \(products)")
            await withUnsafeContinuation { cont in
                DispatchQueue.main.async {
                    self.productState = .loaded
                    self.products = products
                    cont.resume()
                }
            }
        } catch {
            logger.error("could not load products: \(error)")
            await update(productState: .error(cause: error))
        }
    }
    
    private func update(subscriptionState: SubscriptionState) async {
        await withUnsafeContinuation { cont in
            DispatchQueue.main.async {
                self.subscriptionState = subscriptionState
                cont.resume()
            }
        }
    }
    
    private func update(productState: ProductState) async {
        await withUnsafeContinuation { cont in
            DispatchQueue.main.async {
                logger.debug("set productState to: \(productState)")
                self.productState = productState
                cont.resume()
            }
        }
    }
}
