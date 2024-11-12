//
//  ContentView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI

struct ContentView: View {
    @State private var visibility: NavigationSplitViewVisibility = .all
    @Environment(ViewModel.self) private var viewModel

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            
            PlayListView().environment(viewModel)
            
        } content: {
            ContentUnavailableView("Select a playlist", systemImage: "doc.text.image.fill")
        } detail: {
            ContentUnavailableView("Select a song", systemImage: "doc.text.image.fill")
        }
        .navigationSplitViewStyle(.automatic)
        .preferredColorScheme(viewModel.displayMode == .dark ? .dark : (viewModel.displayMode == .light ? .light : nil))
    }
}
