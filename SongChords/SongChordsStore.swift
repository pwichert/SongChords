//
//  SongChordsStore.swift
//  SongChords
//
//  Created by Peter Wichert on 03.01.25.
//

import SwiftUI
import StoreKit

typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}

public enum ProductId: String {
    case songLimit = "iap.songlimit"
}

@Observable
final class SongChordsStore: @unchecked Sendable {
    @MainActor
    private(set) var products: [Product] = []
    
    @MainActor
    private(set) var purchasedProducts: [Product] = []
    
    private let productIds = [ProductId.songLimit.rawValue]
    let freeSongLimit = 5
    
#if DEBUG
    let certificate = "StoreKitTestCertificate"
#else
    let certificate = "AppleIncRootCertificate"
#endif
    
    private let taskManager = TaskManager()
    
    // Leider können nicht alle Properties in den Actor wandern, da z.B unlockedSongLimit()
    // in synchronen Umgebungen benötigt wird. Und daraus kann keine synchrone Function gemacht werden(?).
    // Also bleiben sie erstmal MainActor-synchronisiert.
    actor TaskManager {
        private var updateListenerTask: Task<Void, Error>? = nil
        
        func stopListener() {
            print("stop listener")
            updateListenerTask?.cancel()
            updateListenerTask = nil
        }
        
        func runListener(store: SongChordsStore) {
            // Wird vom Scenenwechsel mehrfach unnütz aufgerufen, insb. beim Kaufen (Wechsel .active <-> .inactive)
            // Daher nicht neu starten, falls er schon läuft.
            guard updateListenerTask == nil else { return }
            
            print("start listener")
            updateListenerTask = store.listenForTransactions()
        }
    }
    
    init() {
        Task {
            await taskManager.runListener(store: self)

            //During store initialization, request products from the App Store.
            await requestProducts()

            //Deliver products that the customer purchases.
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        print("deinit")
        
        Task { [weak self] in
            await self?.taskManager.stopListener()
        }
    }
    
    func stopListener() async {
        await taskManager.stopListener()
    }
    
    func runListener() async {
        await taskManager.runListener(store: self)
    }
    
    @MainActor
    func updateProducts(product: Product) {
        products.append(product)
    }

    @MainActor
    func setPurchasedProducts(product: [Product]) {
        purchasedProducts = product
    }

    @MainActor
    func unlockedSonglimit() -> Bool {
        return isPurchasedId(ProductId.songLimit.rawValue)
    }
    
    @MainActor
    func isUnlocked() -> Bool {
        products.allSatisfy({ isPurchased($0) })
    }
    
    @MainActor
    func isPurchased(_ product: Product) -> Bool {
        //Determine whether the user purchases a given product.
        
        // Caching, falls kein Netz o.ä.
//        if UserDefaults.standard.bool(forKey: product.id) { return true }

        return purchasedProducts.contains(product)
    }
    
    @MainActor
    func isPurchasedId(_ productID: String) -> Bool {
        //Determine whether the user purchases a given productID.
        
        // Caching, falls kein Netz o.ä.
//        if UserDefaults.standard.bool(forKey: productID) { return true }
        
        if let product = products.first(where: { $0.id == productID }) {
            return purchasedProducts.contains(product)
        }
        return false
    }

    func listenForTransactions() -> Task<Void, Error> {
        return Task(priority: .background) {
            print("Store: listenForTransactions")
            
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            
            for await result in Transaction.updates {
                print("Store: listenForTransactions update: \(result.debugDescription)")
                do {
                    let transaction = try self.checkVerified(result)
                    
                    //Deliver products to the user.
                    await self.updateCustomerProductStatus()
                    
                    //Always finish a transaction.
                    await transaction.finish()
                } catch {
                    //StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
            
            if Task.isCancelled { print("listener cancelled")}
        }
    }
        
    func requestProducts() async {
        do {
            //Request products from the App Store using the identifiers that the Products.plist file defines.
            let storeProducts = try await Product.products(for: productIds)

            //Filter the products into categories based on their type.
            for product in storeProducts {
                await updateProducts(product: product)
            }
        } catch {
            print("Failed product request from the App Store server: \(error)")
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            //The result is verified. Return the unwrapped value.
            return safe
        }
    }

    func updateCustomerProductStatus() async {
        var purchasedProducts: [Product] = []

        //Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try checkVerified(result)

                //Check the `productType` of the transaction and get the corresponding product from the store.
                switch transaction.productType {
                case .nonConsumable:
                    if let product = await products.first(where: { $0.id == transaction.productID }) {
                        if transaction.revocationDate == nil {
                            purchasedProducts.append(product)
                            // Caching
                            UserDefaults.standard.set(true, forKey: product.id)
                        } else {
                            // kommt bei Transaction.currentEntitlements hier nicht vorbei, da nur die gültigen gelesen werden.
                            // Führt natürlich dazu, dass zurückgegebene Käufe im Cache nicht bemerkt werden: einmal kaufen, zurückgeben, trotzdem weiternutzen...
                            UserDefaults.standard.removeObject(forKey: product.id)
                        }
                    }
                default:
                    break
                }
            } catch {
                print(error)
            }
        }

        //Update the store information with the purchased products.
        await setPurchasedProducts(product: purchasedProducts)
    }
    
    //    func purchase(_ product: Product) async throws -> Transaction? {
    //        //Begin purchasing the `Product` the user selects.
    //        let result = try await product.purchase()
    //
    //        switch result {
    //        case .success(let verification):
    //            //Check whether the transaction is verified. If it isn't,
    //            //this function rethrows the verification error.
    //            let transaction = try checkVerified(verification)
    //
    //            //The transaction is verified. Deliver content to the user.
    //            await updateCustomerProductStatus()
    //
    //            //Always finish a transaction.
    //            await transaction.finish()
    //
    //            return transaction
    //        case .userCancelled, .pending:
    //            return nil
    //        default:
    //            return nil
    //        }
    //    }
}
