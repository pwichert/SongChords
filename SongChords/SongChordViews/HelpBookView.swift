//
//  HelpBookView.swift
//  SongChords
//
//  Created by Peter Wichert on 26.01.26.
//

import SwiftUI

struct HelpBookView: View {
    @State private var loader: HelpBookLoader
    @State private var helpColumns: NavigationSplitViewVisibility = .all
    let vers: String
    
    @Environment(\.dismiss) private var dismiss

    init(initialChapter: String? = nil) {
        self.loader = HelpBookLoader(initialChapter: initialChapter)
        let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? ""
        let appVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
        let appBuild = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? ""
        vers = "\(appName) \(appVersion) (\(appBuild))"
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $helpColumns) {
            List(loader.chapters, selection: $loader.currentID) { chapter in
                Text(chapter.title)
            }
            .navigationTitle("SongChords Help")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Text(vers).fixedSize(horizontal: true, vertical: false).padding(.horizontal)
                }.sharedBackgroundVisibility(.hidden)
            }
            #endif
            #if os(macOS)
            Text(vers).fixedSize(horizontal: true, vertical: false).padding()
            #endif
        } detail: {
            if let current = loader.currentID, let chapter = loader.chapters.first(where: { $0.id == current }) {
                let nodes = MarkdownParser.parse(loader.loadMarkdown(chapter))
                
                // ScrollView truncated den Text in iOS manchmal. Form nicht. ???
                #if os(macOS)
                ScrollView {
                    MarkdownView(nodes: nodes)
                        .padding()
                }.id(current)   // scroll top
                .navigationTitle(chapter.title)
                #else
                Form {
                    MarkdownView(nodes: nodes)
                }.id(current)   // scroll top
                .scrollContentBackground(.hidden)
                .navigationTitle(chapter.title)
                .navigationBarTitleDisplayMode(.large)
                #endif
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
