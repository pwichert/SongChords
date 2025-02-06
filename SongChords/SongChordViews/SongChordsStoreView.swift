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
                if store.isPurchasedId(productId.rawValue) {
                    // Ist schon gekauft
                    Text("Have fun!").font(.headline).padding()
                    VStack {
                        HStack {
                            Spacer()
                            Button("Ok") { dismiss() }
                            Spacer()
                        }.buttonStyle(.bordered)
                    }.padding()
                } else if store.products.isEmpty {
                    // Produkte noch nicht geladen
                    Text("Loading products...").font(.headline).padding()
                    VStack {
                        HStack {
                            Spacer()
                            Button("Cancel") { dismiss() }
                            Spacer()
                        }.buttonStyle(.bordered)
                    }.padding()
                } else {
                    // Kaufen des Purchase-Produkts
                    Text(scError.desc).font(.headline)
                        .lineLimit(nil)
                        .multilineTextAlignment(.center).padding()
                    
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
        .frame(width: 350, height: 400)
        #endif
    }
}
