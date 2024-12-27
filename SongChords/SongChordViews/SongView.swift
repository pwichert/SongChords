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

    @Environment(UserSettings.self) private var userSettings
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext

    @State private var showSongEditView: Bool = false
    @State private var showShareView: Bool = false
    @State private var pdfUrl: URL?
    
    @State private var showFileExport: Bool = false
    @State private var uttype: UTType = .pdf
    
    var body: some View {
        GeometryReader { viewSize in    // Größe des umgebenden Containers
            ScrollView(userSettings.hidechords ? .vertical : [.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    if let pdfUrl = pdfUrl {
                        PDFKitView(url: pdfUrl)
                        #if os(iOS)
                            .navigationBarTitleDisplayMode(.inline)
                        #endif
                    } else {
                        DetailContent(song: song, representationHolder: song.representationHolder)
                        #if os(iOS)
                            .navigationBarTitleDisplayMode(.automatic)
                        #endif
                    }
                    
                    Color.clear.frame(width: 1, height: viewSize.size.height, alignment: .center)
                    Color.clear.frame(width: viewSize.size.width, height: 1, alignment: .center)
                }.padding(0)
            }
        }
        .navigationTitle(song.title)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                if horizontalSizeClass == .regular && visibility != .detailOnly {
                    Button("Detailed View", systemImage: "sidebar.left", action: { visibility = .detailOnly }).help("Detailed View")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    ShareLink (
                        item: pdfUrl != nil ? song.setTransPDF() : song.setTransCodable(), preview: SharePreview(Text(song.title), image: Image("AppIconInternal"))
                    )
                }.padding(.horizontal)   // TODO funktioniert nicht
            }
            #endif
            ToolbarItem {
                Button("ChordPro Text", systemImage: "pencil", action: { showSongEditView.toggle() }).help("Edit ChordPro Text")
            }
            ToolbarItem {
                Button("Toggle PDF", systemImage: pdfUrl == nil ? "text.rectangle.page" : "text.page", action: { if pdfUrl == nil { showPdf() } else { pdfUrl = nil } }).help("Toggle PDF")
            }
            #if os(macOS) // in iOS durch ShareLink ersetzt
            ToolbarItem {
                Button("Export PDF File", systemImage: "arrow.up.document.fill", action: { uttype = .pdf; song.setTransAll(); showFileExport.toggle() }).help("Export PDF File")
            }
            ToolbarItem {
                Button("Export Song", systemImage: "arrow.up.document", action: { uttype = .songJSON; song.setTransAll();showFileExport.toggle() }).help("Export Song")
            }
            #endif
            #if false
            ToolbarItem {
                Button("Share View", systemImage: "square.and.arrow.up.circle.fill", action: { showShareView.toggle() }).help("Share")
            }
            #endif
        }
        .sheet(isPresented: $showSongEditView) {
            NavigationStack {
                SongEditView(playlist: song.playlist!, song: song)
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showShareView) {
            NavigationStack {
                ShareView(song: song)
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
        let delegate = PrintSongDelegate(songID: song.persistentModelID, modelContainer: modelContext.container)
        if let delegate = delegate {
            let defaultPaper = MediaBoxes.getBox(name: userSettings.mediabox)
            pdfUrl = delegate.createPDF(paperSize: defaultPaper)
        }
    }
    
    @MainActor
    private func onPrint() {
        let delegate = PrintSongDelegate(songID: song.persistentModelID, modelContainer: modelContext.container)
        if let delegate = delegate {
            PrintController.onPrint(title: song.title, delegate: delegate)
        }
    }
}

struct DetailContent: View {
    let song: Song
    @ObservedObject var representationHolder: RepresentationHolder

    @Environment(UserSettings.self) private var userSettings
    
    @State private var darkColor = Color.init(red: 0.25, green: 0.25, blue: 0.25)
    #if os(macOS)
    @State private var lightColor = Color.init(red: 0.85, green: 0.85, blue: 0.85)
    #else
    @State private var lightColor = Color.init(red: 0.90, green: 0.90, blue: 0.90)
    #endif

    var body: some View {
        VStack (alignment: .leading) {
            #if os(macOS)
            Text(song.title).font(.title).fontWeight(.bold).padding(.bottom, 10)
            #endif
//            let _ = Self._printChanges()
            
            ForEach(representationHolder.songRepresentation.sections) { section in
                SectionHeaderView(section: section, lightColor: lightColor, darkColor: darkColor).font(Font(userSettings.headerUIFont))
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                ForEach(section.splittedLines) { line in
                    if userSettings.hidechords && line.texts.isEmpty && !line.chords.isEmpty {
                        // bei hidechords sollen alle Zeilen verschwinden und auch kein linespacing machen, die nur chords haben 
                        EmptyView()
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            if line.chords.isEmpty && line.texts.isEmpty {
                                // Leerzeile
                                Text(" ").font(Font(userSettings.txtUIFont))
                            } else if userSettings.hidechords {
                                // ist nicht leer
                                Text(line.plainText).font(Font(userSettings.txtUIFont))
                            } else {
                                ChordsLineView(line: line, lightColor: lightColor, darkColor: darkColor).font(Font(userSettings.chordUIFont))
                                TextsLineView(line: line).font(Font(userSettings.txtUIFont))
                            }
                        }.padding(EdgeInsets(top: 0, leading: 0, bottom: userSettings.linespacing, trailing: 0))
                    }
                }
            }
        }.padding()
        .onChange(of: song, initial: true) { print("song changed"); updateSongRepresentation() }
        .onChange(of: userSettings.chordsize, initial: false) { print("chordsize changed"); updateSongRepresentation() }
        .onChange(of: userSettings.txtsize, initial: false) { print("txtsize changed"); updateSongRepresentation() }
        .onChange(of: userSettings.headersize, initial: false) { print("headersize changed"); updateSongRepresentation() }
        .onChange(of: userSettings.isGermanNotation, initial: false) { print("isGermanNotation changed"); updateSongRepresentation() }
        .onChange(of: userSettings.textfollowschords, initial: false) { print("textfollowschords changed"); updateSongRepresentation() }
    }
    
    private func updateSongRepresentation() {
        song.processSongInBackground(userSettings: userSettings, forPrinting: false)
    }
}

struct SectionHeaderView: View {
    let section: CPPSection
    let lightColor: Color
    let darkColor: Color
    let showHeader: Bool = true
    
    @Environment(UserSettings.self) private var userSettings
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
    
    @Environment(UserSettings.self) private var userSettings
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


struct ShareView: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            ShareLink (item: song, preview: SharePreview(Text(song.title), image: Image("AppIconInternal")))
            ShareLink (item: song.srcText, subject: Text(song.title), preview: SharePreview(Text(song.title), image: Image("AppIconInternal")))
            ShareLink (item: try! song.toData(), subject: Text(song.title), preview: SharePreview(Text(song.title), image: Image("AppIconInternal")))
        }
        .frame(idealHeight: 500)
        .navigationTitle("Share")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ok") {
                    dismiss()
                }
            }
        }
    }
}
