//
//  SongChordsStoreView.swift
//  SongChords
//
//  Created by Peter Wichert on 03.01.25.
//

import SwiftUI
import StoreKit

struct SongChordsStoreView: View {
    let store: SongChordsStore
    let songChordsError: EquatableError?

    let mapErrorToProduct: [SongChordsError:ProductId] = [ SongChordsError.limitReached : ProductId.songLimit ]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("SongChords Unlock").font(.title)
                .lineLimit(nil)
                .multilineTextAlignment(.center).padding()

            if let scError = (songChordsError?.error as? SongChordsError), let productId = mapErrorToProduct[scError] {
                Text(scError.desc).font(.headline)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center).padding()
                
                if store.products.isEmpty {
                    Text("Loading products...").font(.headline).padding()
                    VStack {
                        HStack {
                            Spacer()
                            Button("Cancel") { dismiss() }
                            Spacer()
                        }.buttonStyle(.bordered)
                    }.padding()
                } else {
                    ProductView(id: productId.rawValue) {
                        Image(systemName: "crown")
                    }
                    .productViewStyle(.compact)
                    .buttonStyle(.borderedProminent)
                    .padding().border(Color.secondary)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button("No, thanks") { dismiss() }
                            Spacer()
                        }
                        
                        HStack {
                            Spacer()
                            Button("Restore Purchases", action: {
                                Task {
                                    //This call displays a system prompt that asks users to authenticate with their App Store credentials.
                                    //Call this function only in response to an explicit user action, such as tapping a button.
                                    try? await AppStore.sync()
                                }
                            })
                            Spacer()
                        }
                    }.buttonStyle(.bordered)
                    .padding()
                }
            } else {
                Text("Internal Error").font(.headline).padding()
                VStack {
                    HStack {
                        Spacer()
                        Button("Cancel") { dismiss() }
                        Spacer()
                    }.buttonStyle(.bordered)
                }.padding()
            }
        }.padding()
        #if os(macOS)
        .frame(width: 450, height: 500)
        #endif
    }
}

//struct PurchaseView: View {
//    let store: SongChordsStore
//    @Environment(\.dismiss) private var dismiss
//
//    var body: some View {
//        VStack {
//            if store.products.isEmpty {
//                Text("in-App-Purchase Error:")
//                Text("no Products available")
//                Button("Ok", role: nil) {
//                    dismiss()
//                }.padding()
//            } else {
//                if store.purchasedProducts.isEmpty {
//                    Text("Do you like the app and want to manage more than 4 songs? Then you can permanently unlock the app with a one-time in-app purchase:").lineLimit(nil)
//                    
//                    ForEach(store.products) { product in
//                        ProductView(id: product.id)
//                    }.padding()
//                    
//                    Divider().padding()
//                    
//                    Button("Restore Purchases", action: {
//                        Task {
//                            //This call displays a system prompt that asks users to authenticate with their App Store credentials.
//                            //Call this function only in response to an explicit user action, such as tapping a button.
//                            try? await AppStore.sync()
//                        }
//                    })
//                    
//                    Button("No, thanks", role: nil) {
//                        dismiss()
//                    }.padding()
//                } else {
//                    Text("Thank you for unlocking the app!").lineLimit(nil)
//                    
//                    ForEach(store.products) { product in
//                        ProductView(id: product.id)
//                    }
//                    
//                    Divider().padding()
//                    
//                    Button("Ok", role: nil) {
//                        dismiss()
//                    }.padding()
//                }
//            }
//        }
//        .padding(20)
//        #if os(macOS)
//        .frame(width: 500)
//        #else
//        .frame(maxWidth: 500)
//        .border(Color.gray, width: 1)
//        .padding(10)
//        #endif
//    }
//}
