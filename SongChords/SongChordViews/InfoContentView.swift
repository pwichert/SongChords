//
//  InfoContentView.swift
//  SongChords
//
//  Created by Peter Wichert on 28.11.24.
//

import SwiftUI

struct InfoContentView<Content: View>: View {
    let navigationTitle: String
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss
    
    init(_ navigationTitle: String, @ViewBuilder content: () -> Content) {
        self.navigationTitle = navigationTitle
        self.content = content()
    }
    
    var body: some View {
        #if os(macOS)
        ScrollView {
            content
                .padding()
        }
        .frame(idealHeight: 500)
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ok", systemImage: "checkmark") {
                    dismiss()
                }
            }
        }
        #else
        Form {
            content
                .font(.footnote)
                .padding()
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ok", systemImage: "checkmark") {
                    dismiss()
                }
            }
        }
        #endif
    }
}
