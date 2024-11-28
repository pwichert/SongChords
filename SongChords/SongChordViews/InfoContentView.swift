//
//  InfoContentView.swift
//  SongChords
//
//  Created by Peter Wichert on 28.11.24.
//

import SwiftUI

struct InfoContentView<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if os(macOS)
        ScrollView {
            content
                .padding()
        }
        .frame(idealHeight: 500)
        .navigationTitle("Info")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ok") {
                    dismiss()
                }
            }
        }
        #else
        Form {
            content
                .padding()
        }
        .font(.footnote)
        .navigationTitle("Info")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ok") {
                    dismiss()
                }
            }
        }
        #endif
    }
}
