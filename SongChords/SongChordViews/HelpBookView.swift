//
//  HelpBookView.swift
//  SongChords
//
//  Created by Peter Wichert on 26.01.26.
//

import SwiftUI

struct HelpBookView: View {
    @State private var loader: HelpBookLoader
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var helpColumns: NavigationSplitViewVisibility = .all
    
    @Environment(\.dismiss) private var dismiss

    init(initialChapter: String? = nil) {
        self.loader = HelpBookLoader(initialChapter: initialChapter)
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $helpColumns) {
            List(loader.chapters, selection: $loader.currentID) { chapter in
                Text(chapter.title)
            }
            .navigationTitle("SongChords Help")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        } detail: {
            if let current = loader.currentID, let chapter = loader.chapters.first(where: { $0.id == current }) {
                let nodes = MarkdownParser.parse(loader.loadMarkdown(chapter))
                
                ScrollView {
                    MarkdownView(nodes: nodes)
                        .padding()
                }
                .navigationTitle(chapter.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
                .onChange(of: current) { scrollPosition = ScrollPosition(edge: .top) }
                .scrollPosition($scrollPosition)
            } else {
                ContentUnavailableView("Select a topic", systemImage: "book")
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear { loader.load() }
        #if os(macOS)
        .frame(idealWidth: 350, idealHeight: 600)
        #endif
    }
}
