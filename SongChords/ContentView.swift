//
//  ContentView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI

struct ContentView: View {
    @State private var visibility: NavigationSplitViewVisibility = .all
        
        var body: some View {
            NavigationSplitView(columnVisibility: $visibility) {

                PlayListView()

            } content: {
                ContentUnavailableView("Select an element from the sidebar", systemImage: "doc.text.image.fill")
            } detail: {
                ContentUnavailableView("Select an element from the list", systemImage: "doc.text.image.fill")
            }
        }
}

struct CategoryView: View {
    let category: String

    var body: some View {
        List {
            NavigationLink("\\(category) Item 1", destination: DetailView(item: "\\(category) Item 1"))
            NavigationLink("\\(category) Item 2", destination: DetailView(item: "\\(category) Item 2"))
        }
        .navigationTitle("Content")
    }
}

struct DetailView: View {
    let item: String

    var body: some View {
        Text("Details for \\(item)")
            .navigationTitle("Detail")
    }
}
