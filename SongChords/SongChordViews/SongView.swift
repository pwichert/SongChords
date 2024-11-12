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
                    .frame(minWidth: max(viewSize.size.width, contentSize.width),
                           minHeight: max(viewSize.size.height, contentSize.height), alignment: .topLeading)
            }
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
            Text(song.title).font(.title).fontWeight(.bold).padding(.bottom, 20)
//            let _ = Self._printChanges()
            
            ForEach(representationHolder.songRepresentation.sections) { section in
                SectionHeaderView(section: section)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                ForEach(section.splittedLines) { line in
                    VStack(alignment: .leading, spacing: 0) {
                        if line.chords.isEmpty && line.texts.isEmpty {
                            // Leerzeile
                            Text(" ").font(Font(viewModel.txtUIFont))
                        } else {
                            ChordsLineView(line: line)
                            TextsLineView(line: line)
                        }
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: viewModel.linespacing, trailing: 0))
                }
            }
        }.padding()
        .onChange(of: song, initial: true) {
            print("song changed")
            song.processSongInBackground(viewModel: viewModel)
        }
        .onChange(of: viewModel.chordsize, initial: false) {
            print("chordsize changed")
            song.processSongInBackground(viewModel: viewModel)
        }
        .onChange(of: viewModel.txtsize, initial: false) {
            print("txtsize changed")
            song.processSongInBackground(viewModel: viewModel)
        }
        .onChange(of: viewModel.headersize, initial: false) {
            print("headersize changed")
            song.processSongInBackground(viewModel: viewModel)
        }
    }
}


struct SectionHeaderView: View {
    var section: Section
    var showHeader: Bool = true
    
    @Environment(ViewModel.self) private var viewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if showHeader && section.name.trimmingCharacters(in: .whitespaces).count > 0 {
            HStack(alignment: .center) {
                Text(section.name)
                    .font(Font(viewModel.headerUIFont))
                    .padding(.leading, 3)
                Spacer()
            }
            .padding(1)
            .background(colorScheme == .dark ? Color.init(red: 0.25, green: 0.25, blue: 0.25) : Color.init(red: 0.85, green: 0.85, blue: 0.85))
            .cornerRadius(5)
        } else {
            HStack {
                Spacer()
            }
        }
    }
}

struct ChordsLineView: View {
    var line: SplittedLine
    
    @Environment(ViewModel.self) private var viewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(line.chords) { chord in
                HStack(alignment: .center, spacing: 0) {
                    Color.clear.frame(width: chord.fontOffset, height: 0.1, alignment: .center)
                    
                    Text(chord.txt)
                        .lineLimit(1)
                        .padding(.horizontal, 0.8)
                        .background(chord.background ? (colorScheme == .dark ? Color.init(red: 0.25, green: 0.25, blue: 0.25) : Color.init(red: 0.85, green: 0.85, blue: 0.85)) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
                }.font(Font(viewModel.chordUIFont))
            }
        }
    }
}

struct TextsLineView: View {
    var line: SplittedLine
    
    @Environment(ViewModel.self) private var viewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(line.texts) { text in
                HStack(alignment: .center, spacing: 0) {
                    Color.clear.frame(width: text.fontOffset, height: 0.1, alignment: .center)
                    
                    Text(text.txt)
                        .lineLimit(1)
                }.font(Font(viewModel.txtUIFont))
            }
        }
    }
}
