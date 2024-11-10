//
//  SongView.swift
//  SongChords
//
//  Created by Peter Wichert on 10.11.24.
//

import SwiftUI

struct SongView: View {
    let song: Song
        
    @State private var contentSize: CGSize = .zero
    @State private var showSongEditView: Bool = false
    
    var body: some View {
        GeometryReader { viewSize in
            ScrollView([.horizontal, .vertical]) {
                DetailContent(song: song)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: {
                        contentSize = $0
                    }
                    .border(.red)
                    .frame(minWidth: max(viewSize.size.width, contentSize.width),
                           minHeight: max(viewSize.size.height, contentSize.height), alignment: .topLeading)
            }
            .border(.yellow)
        }
        .toolbar {
            ToolbarItem {
                Button(action: { showSongEditView.toggle() }, label: { Image(systemName: "pencil") })
            }
        }
        .sheet(isPresented: $showSongEditView) {
            NavigationStack {
                SongEditView(playlist: song.playlist!, song: song)
            }
            .interactiveDismissDisabled()
        }
    }
}

struct DetailContent: View {
    let song: Song
    
    var body: some View {
        VStack (alignment: .leading) {
            Text(song.title).font(.title2).padding(.bottom, 20)
            
            ForEach(song.songRepresentation?.sections ?? []) { section in
                Text(section.name)
                
                ForEach(section.lines) { line in
                    
                }
            }
        }
        .onChange(of: song.srcText, initial: true) {
            print("srcText changed")
            song.toSongRepresentation()
        }
        .onChange(of: song.transpose, initial: false) {
            print("transpose changed")
            song.toSongRepresentation()
        }
    }
}
