//
//  SongChordsStoreView.swift
//  SongChords
//
//  Created by Peter Wichert on 03.01.25.
//

import SwiftUI
import StoreKit

struct SongChordsStoreView: View {
    
    var body: some View {
        Text("Welcome to my store")
                .font(.title)

            ProductView(id: "com.hackingwithswift.plus.subscription") {
                Image(systemName: "crown")
            }
            .productViewStyle(.compact)
            .padding()
    }
}
