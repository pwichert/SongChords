//
//  SongView.swift
//  SongChords
//
//  Created by Peter Wichert on 10.11.24.
//

import SwiftUI
import UniformTypeIdentifiers

struct SongView: View {
    var song: Song

    @Environment(ViewModel.self) private var viewModel

    @State private var contentSize: CGSize = .zero
    @State private var showSongEditView: Bool = false
    @State private var pdfUrl: URL?
    @State private var showFileExport: Bool = false
    @State private var showPDFExport: Bool = false
    @State private var uttype: UTType = .plainText
    
    var body: some View {
        GeometryReader { viewSize in    // Größe des umgebenden Containers
            ScrollView([.horizontal, .vertical]) {
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
            ToolbarItem {
                Button("ChordPro Text", systemImage: "pencil", action: { showSongEditView.toggle() }).help("Edit ChordPro Text")
            }
            ToolbarItem {
                Button("Toggle PDF", systemImage: pdfUrl == nil ? "text.viewfinder" : "text.alignleft", action: { if pdfUrl == nil { showPdf() } else { pdfUrl = nil } }).help("Toggle PDF")
            }
            ToolbarItem {
                Button("Export PDF file", systemImage: "arrow.up.document", action: { uttype = .pdf; showPDFExport.toggle() }).help("Export PDF file")
            }
            #if true// && os(iOS)
            ToolbarItem {
                ShareLink(
                    item: song.saveDataToFile(filename: "\(song.title).chpro")!,
                    preview: SharePreview(song.title, image: Image(systemName: "doc.text"))
                ).help("Share")
            }
            #else
            ToolbarItem {
                Button("Export ChordPro file", systemImage: "square.and.arrow.up", action: { uttype = .plainText; showPDFExport.toggle() }).help("Export ChordPro file")
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
        .fileExporter(isPresented: $showPDFExport, item: song, contentTypes: [uttype], defaultFilename: song.title) { result in
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
    var song: Song
    @ObservedObject var representationHolder: RepresentationHolder

    @Environment(ViewModel.self) private var viewModel
    
    var body: some View {
        VStack (alignment: .leading) {
            Text(song.title).font(.title).fontWeight(.bold).padding(.bottom, 20)
//            let _ = Self._printChanges()
            
            ForEach(representationHolder.songRepresentation.sections) { section in
                SectionHeaderView(section: section)
                    .font(Font(viewModel.headerUIFont))
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                ForEach(section.splittedLines) { line in
                    VStack(alignment: .leading, spacing: 0) {
                        if line.chords.isEmpty && line.texts.isEmpty {
                            // Leerzeile
                            Text(" ").font(Font(viewModel.txtUIFont))
                        } else {
                            if !viewModel.hidechords { ChordsLineView(line: line).font(Font(viewModel.chordUIFont)) }
                            TextsLineView(line: line).font(Font(viewModel.txtUIFont))
                        }
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: viewModel.linespacing, trailing: 0))
                }
            }
        }.padding()
        .onChange(of: song, initial: true) {
            print("song changed")
            song.processSongInBackground(viewModel: viewModel, forPrinting: false)
        }
        .onChange(of: viewModel.chordsize, initial: false) {
            print("chordsize changed")
            song.processSongInBackground(viewModel: viewModel, forPrinting: false)
        }
        .onChange(of: viewModel.txtsize, initial: false) {
            print("txtsize changed")
            song.processSongInBackground(viewModel: viewModel, forPrinting: false)
        }
        .onChange(of: viewModel.headersize, initial: false) {
            print("headersize changed")
            song.processSongInBackground(viewModel: viewModel, forPrinting: false)
        }
        .onChange(of: viewModel.isGermanNotation, initial: false) {
            print("isGermanNotation changed")
            song.processSongInBackground(viewModel: viewModel, forPrinting: false)
        }
        .onChange(of: viewModel.textfollowschords, initial: false) {
            print("textfollowschords changed")
            song.processSongInBackground(viewModel: viewModel, forPrinting: false)
        }
        .onChange(of: viewModel.hidechords, initial: false) {
            print("dontshowchords changed")
            song.processSongInBackground(viewModel: viewModel, forPrinting: false)
        }
    }
}

struct SectionHeaderView: View {
    var section: CPPSection
    var showHeader: Bool = true
    
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
                }
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
                }
            }
        }
    }
}
