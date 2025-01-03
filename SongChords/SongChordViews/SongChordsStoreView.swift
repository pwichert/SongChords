//
//  SongChordsStoreView.swift
//  SongChords
//
//  Created by Peter Wichert on 03.01.25.
//

import SwiftUI
import StoreKit

struct SongChordsStoreView: View {
    var store: SongChordsStore
    
    var body: some View {
        VStack {
            Text("SongChords Store")
                .font(.headline)
            
            if let product = store.products.first {
                ProductView(id: product.id) {
                    Image(systemName: "crown")
                }
                .productViewStyle(.compact)
                .onInAppPurchaseStart { product in
                    print("User has started buying \(product.id)")
                }
                .onInAppPurchaseCompletion { product, result in
                    if case .success(.success(let transaction)) = result {
                        print("Purchased successfully: \(transaction.signedDate)")
                    } else {
                        print("Something else happened")
                    }
                }
            } else {
                Text("No products available").font(.subheadline)
            }
        }
        .foregroundStyle(.secondary)
        .padding()
    }
}
