//
//  SongView.swift
//  SongChords
//
//  Created by Peter Wichert on 10.11.24.
//

import SwiftUI
import UniformTypeIdentifiers

struct SongView: View {
    let song: Song
    @Binding var visibility: NavigationSplitViewVisibility

    @Environment(ViewModel.self) private var viewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var showSongEditView: Bool = false
    @State private var pdfUrl: URL?
    
    @State private var showFileExport: Bool = false
    @State private var uttype: UTType = .pdf
    
    var body: some View {
        GeometryReader { viewSize in    // Größe des umgebenden Containers
            ScrollView(viewModel.hidechords ? .vertical : [.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    if let pdfUrl = pdfUrl {
                        PDFKitView(url: pdfUrl)
                    } else {
                        DetailContent(song: song, representationHolder: song.representationHolder)
                    }
                    
                    Color.clear.frame(width: 1, height: viewSize.size.height, alignment: .center)
                    Color.clear.frame(width: viewSize.size.width, height: 1, alignment: .center)
                }.padding(0)
            }
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                if horizontalSizeClass == .regular && visibility != .detailOnly {
                    Button("Detailed View", systemImage: "sidebar.left", action: { visibility = .detailOnly }).help("Detailed View")
                }
            }
            #endif
            ToolbarItem {
                Button("ChordPro Text", systemImage: "pencil", action: { showSongEditView.toggle() }).help("Edit ChordPro Text")
            }
            ToolbarItem {
                Button("Toggle PDF", systemImage: pdfUrl == nil ? "document.viewfinder.fill" : "text.alignleft", action: { if pdfUrl == nil { showPdf() } else { pdfUrl = nil } }).help("Toggle PDF")
            }
            ToolbarItem {
                Button("Export PDF File", systemImage: "arrow.up.document.fill", action: { uttype = .pdf; showFileExport.toggle() }).help("Export PDF File")
            }
            #if os(macOS) // ... solange der ShareLink auf macOS nicht funktioniert.
            ToolbarItem {
                Button("Export Song", systemImage: "arrow.up.document", action: { uttype = .songJSON; showFileExport.toggle() }).help("Export Song")
            }
            #endif
            #if os(iOS) || DEBUG
            ToolbarItem {
                ShareLink (
                    item: song, preview: SharePreview(song.title, image: Image(systemName: "text.page"))
                )
            }
            #endif
        }
        .sheet(isPresented: $showSongEditView) {
            NavigationStack {
                SongEditView(playlist: song.playlist!, song: song)
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: song, initial: false) {
            if pdfUrl != nil {
                print("pdfUrl changed")
                pdfUrl = nil
            }
        }
        .fileExporter(isPresented: $showFileExport, item: song, contentTypes: [uttype], defaultFilename: song.title) { result in
            switch result {
            case .success(let url):
                print("Gespeichert: \(url)")
            case .failure(let error):
                print("Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func showPdf() {
        let delegate = PrintSongDelegate(viewModel: viewModel, song: song)
        let defaultPaper = MediaBoxes.getBox(name: viewModel.mediabox)
        pdfUrl = delegate.createPDF(paperSize: defaultPaper)
    }
    
    @MainActor
    private func onPrint() {
        let delegate = PrintSongDelegate(viewModel: viewModel, song: song)
        PrintController.onPrint(viewModel: viewModel, title: song.title, delegate: delegate)
    }
}

struct DetailContent: View {
    let song: Song
    @ObservedObject var representationHolder: RepresentationHolder

    @Environment(ViewModel.self) private var viewModel
    
    @State private var darkColor = Color.init(red: 0.25, green: 0.25, blue: 0.25)
    #if os(macOS)
    @State private var lightColor = Color.init(red: 0.85, green: 0.85, blue: 0.85)
    #else
    @State private var lightColor = Color.init(red: 0.90, green: 0.90, blue: 0.90)
    #endif

    var body: some View {
        VStack (alignment: .leading) {
            Text(song.title).font(.title).fontWeight(.bold).padding(.bottom, 10)
//            let _ = Self._printChanges()
            
            ForEach(representationHolder.songRepresentation.sections) { section in
                SectionHeaderView(section: section, lightColor: lightColor, darkColor: darkColor).font(Font(viewModel.headerUIFont))
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                ForEach(section.splittedLines) { line in
                    if viewModel.hidechords && line.texts.isEmpty && !line.chords.isEmpty {
                        // bei hidechords sollen alle Zeilen verschwinden und auch kein linespacing machen, die nur chords haben 
                        EmptyView()
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            if line.chords.isEmpty && line.texts.isEmpty {
                                // Leerzeile
                                Text(" ").font(Font(viewModel.txtUIFont))
                            } else if viewModel.hidechords {
                                // ist nicht leer
                                Text(line.plainText).font(Font(viewModel.txtUIFont))
                            } else {
                                ChordsLineView(line: line, lightColor: lightColor, darkColor: darkColor).font(Font(viewModel.chordUIFont))
                                TextsLineView(line: line).font(Font(viewModel.txtUIFont))
                            }
                        }.padding(EdgeInsets(top: 0, leading: 0, bottom: viewModel.linespacing, trailing: 0))
                    }
                }
            }
        }.padding()
        .onChange(of: song, initial: true) { print("song changed"); updateSongRepresentation() }
        .onChange(of: viewModel.chordsize, initial: false) { print("chordsize changed"); updateSongRepresentation() }
        .onChange(of: viewModel.txtsize, initial: false) { print("txtsize changed"); updateSongRepresentation() }
        .onChange(of: viewModel.headersize, initial: false) { print("headersize changed"); updateSongRepresentation() }
        .onChange(of: viewModel.isGermanNotation, initial: false) { print("isGermanNotation changed"); updateSongRepresentation() }
        .onChange(of: viewModel.textfollowschords, initial: false) { print("textfollowschords changed"); updateSongRepresentation() }
    }
    
    private func updateSongRepresentation() {
        song.processSongInBackground(viewModel: viewModel, forPrinting: false)
    }
}

struct SectionHeaderView: View {
    let section: CPPSection
    let lightColor: Color
    let darkColor: Color
    let showHeader: Bool = true
    
    @Environment(ViewModel.self) private var viewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if showHeader && section.name.trimmingCharacters(in: .whitespaces).count > 0 {
            HStack(alignment: .center) {
                Text(section.name)
                    .padding(.leading, 3)
                Spacer()
            }
            .padding(1)
            .background(colorScheme == .dark ? darkColor : lightColor)
            .cornerRadius(5)
        } else {
            EmptyView()
        }
    }
}

struct ChordsLineView: View {
    let line: SplittedLine
    let lightColor: Color
    let darkColor: Color
    
    @Environment(ViewModel.self) private var viewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if line.chords.isEmpty {
            EmptyView()
        } else {
            ZStack(alignment: .topLeading) {
                ForEach(line.chords) { chord in
                    HStack(alignment: .center, spacing: 0) {
                        if line.chords.last == chord {
                            Color.clear.frame(width: chord.fontOffset, height: 0.1, alignment: .leading)
                            
                            Text(chord.txt)
                                .lineLimit(1)
                                .padding(.horizontal, 0.8)
                                .background(chord.background ? (colorScheme == .dark ? darkColor : lightColor) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
                        } else {
                            Text(chord.txt)
                                .lineLimit(1)
                                .padding(.horizontal, 0.8)
                                .background(chord.background ? (colorScheme == .dark ? darkColor : lightColor) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
                                .offset(CGSize(width: chord.fontOffset, height: 0))
                        }
                    }
                }
            }
        }
    }
}

struct TextsLineView: View {
    let line: SplittedLine
    
    @Environment(ViewModel.self) private var viewModel

    var body: some View {
        if line.texts.isEmpty {
            EmptyView()
        } else {
            ZStack(alignment: .topLeading) {
                ForEach(line.texts) { text in
                    HStack(alignment: .center, spacing: 0) {
                        if line.texts.last == text {
                            Color.clear.frame(width: text.fontOffset, height: 0.1, alignment: .leading)
                            
                            Text(text.txt)
                                .lineLimit(1)
                        } else {
                            Text(text.txt)
                                .lineLimit(1)
                                .offset(CGSize(width: text.fontOffset, height: 0))
                        }
                    }
                }
            }
        }
    }
}
