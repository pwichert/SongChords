//
//  SongView.swift
//  SongChords
//
//  Created by Peter Wichert on 10.11.24.
//

import SwiftUI

struct SongView: View {
    var song: Song
        
    @State private var contentSize: CGSize = .zero
    @State private var showSongEditView: Bool = false
    
    var body: some View {
        GeometryReader { viewSize in    // Größe des umgebenden Containers
            ScrollView([.horizontal, .vertical]) {
                DetailContent(song: song, representationHolder: song.representationHolder)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: {
                        contentSize = $0    // Größe von DetailContent
                    }
//                    .border(.red)
                    .frame(minWidth: max(viewSize.size.width, contentSize.width),
                           minHeight: max(viewSize.size.height, contentSize.height), alignment: .topLeading)
            }
//            .border(.yellow)
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
    var song: Song
    @ObservedObject var representationHolder: RepresentationHolder

    @Environment(ViewModel.self) private var viewModel

    var body: some View {
        VStack (alignment: .leading) {
            Text(song.title).font(.title2).padding(.bottom, 20)
//            let _ = Self._printChanges()
                        
            ForEach(representationHolder.songRepresentation.sections) { section in
                Text("[ " + section.name + " ]")
                    .font(Font(viewModel.headerUIFont))
                
                ForEach(section.splittedLines) { line in
                    ZStack(alignment: .topLeading) {
                        ForEach(line.chords) { chord in
                            HStack(alignment: .center, spacing: 0) {
                                Color.clear.frame(width: chord.fontOffset, height: 0.1, alignment: .center)
                                
                                Text(chord.txt)
                                    .lineLimit(1)
                                    .padding(.horizontal, 0.8)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
                            }.font(Font(viewModel.chordUIFont))
                        }
                    }
                    Text(line.text ?? "nil")
                        .font(Font(viewModel.txtUIFont))
                }
            }
        }
        .onChange(of: song, initial: true) {
            print("song changed")
            song.processSongInBackground(viewModel: viewModel)
        }
        
        // Entweder hier oder in SongEditView. Ich denke, dass ist die sauberste Lösung...
        
//        .onChange(of: song.srcText, initial: false) {
//            print("srcText changed")
//            song.processSongInBackground(viewModel: viewModel)
//        }
//        .onChange(of: song.transpose, initial: false) {
//            print("transpose changed")
//            song.processSongInBackground(viewModel: viewModel)
//        }
    }
}
