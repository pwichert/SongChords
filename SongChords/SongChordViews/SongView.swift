//
//  SongView.swift
//  SongChords
//
//  Created by Peter Wichert on 10.11.24.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct SongView: View {
    let song: Song
    @Binding var visibility: NavigationSplitViewVisibility

    @Environment(UserSettings.self) private var userSettings
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(Globals.self) private var globals
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(TimerManager.self) private var timerManager

    @State private var showAudioPlayer: Bool = false
    @State private var showSongEditView: Bool = false
    @State private var pdfUrl: URL?
    
    @State private var showFileExport: Bool = false
    
    @State private var currentLoop = PlayerLoop(start: 0, stop: 0, title: "")
    @State private var selectedLoop: PlayerLoop?
    @State private var loopActive: Bool = false
    @State private var songSpeed: Double = 1.0
    @State private var songPitch: Float = 0.0
    @State private var songMP3Uuid: String = ""
    @State private var songPosition: TimeInterval = 0.0

    @State private var lastID: PersistentIdentifier?

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
                            .navigationBarTitleDisplayMode(.large)
                        #endif
                    }
                    
                    Color.clear.frame(width: 1, height: viewSize.size.height, alignment: .center)
                    Color.clear.frame(width: viewSize.size.width, height: 1, alignment: .center)
                }.padding(0)
            }
        }
        .navigationTitle(song.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                if horizontalSizeClass == .regular && visibility != .detailOnly {
                    Button("Detailed View", systemImage: "sidebar.left", action: { visibility = .detailOnly }).help("Detailed View")
                }
            }
            
            ToolbarItem(placement: .bottomBar) {
                ShareLink (
                    item: SongTransferable(from: song, includeCodable: true), preview: SharePreview(Text(song.title), image: Image("AppIconInternal"))
                )
            }
            
            ToolbarItem(placement: .bottomBar) {
                ShareLink(item: SongTransferable(from: song, includePDF: true), preview: SharePreview(song.title, image: Image("AppIconInternal"))) {
                    Label("Export PDF File", systemImage: "arrow.up.document.fill")
                }
            }
            
            ToolbarSpacer(placement: .bottomBar)
            
            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAudioPlayer.toggle()
                    }}) { Label("Audio Player", systemImage: "music.note.list") }
            }
            #endif
            ToolbarItem {
                Button("Edit Song", systemImage: "pencil", action: { pdfUrl = nil; showSongEditView.toggle() }).help("Edit Song")
            }
            ToolbarItem {
                Button("Toggle PDF", systemImage: pdfUrl == nil ? "text.rectangle.page" : "text.page", action: { if pdfUrl == nil { Task { await showPdf() }} else { pdfUrl = nil } }).help("Toggle PDF")
            }
            #if os(macOS)
            ToolbarItem {
                Button("Export Song", systemImage: "arrow.up.document", action: { showFileExport.toggle() }).help("Export Song")
            }
            ToolbarItem {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAudioPlayer.toggle()
                    }}) { Label("Audio Player", systemImage: "music.note.list") }
            }
            #endif
        }
        .overlay(
            Group {
                if showAudioPlayer {
                    AudioPlayerView(song: song, currentLoop: $currentLoop, selectedLoop: $selectedLoop, loopActive: $loopActive, songSpeed: $songSpeed, songPosition: $songPosition, songPitch: $songPitch, songMP3Uuid: $songMP3Uuid)
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                    )
                    .padding()
                }
            }, alignment: .bottom
        )
        .sheet(isPresented: $showSongEditView) {
            NavigationStack {
                if let playlist = song.playlist {
                    SongEditView(playlist: playlist, song: song)
                }
            }
            .interactiveDismissDisabled()
        }
        .fileExporter(isPresented: $showFileExport, item: SongTransferable(from: song, includeCodable: true, includePDF: true), contentTypes: [], defaultFilename: Song.makeValidFilename(song.title)) { result in
            switch result {
            case .success(let url):
                print("Gespeichert: \(url)")
            case .failure(let error):
                globals.setSongChordsError(error: error)
            }
        }
        onChange(of: song.persistentModelID, initial: true) {
            if lastID != song.persistentModelID {
                songChangedAction()
                lastID = song.persistentModelID
            }
        }
    }
    
    private func songChangedAction() {
        print("songChangedAction")
        
        // bei Songwechsel auf Livedarstellung schalten
        if pdfUrl != nil {
            print("pdfUrl changed")
            pdfUrl = nil
        }
        
        initAudio()
    }
    
    private func initAudio() {
        Task { await timerManager.stopTimer() }
        
        if audioPlayer.someIsLoaded { audioPlayer.stopAll() }

        songPitch = 0

        if song.musicItemId.starts(with: "local@") {
            audioPlayer.isMP3Player = true
            do {
                let (uuid, pitch) = try song.getMP3Info()
                songPitch = pitch / 10.0
                songMP3Uuid = uuid
            } catch (let error) {
                print(error.localizedDescription)
            }
        } else {
            audioPlayer.isMP3Player = false
        }

        audioPlayer.songSpeed = Float(songSpeed)
        loopActive = false
        currentLoop = PlayerLoop(start: 0, stop: 0, title: "")
        selectedLoop = nil
    }
    
    private func showPdf() async {
        let delegate = await PrintSongDelegate(songID: song.persistentModelID, modelContainer: modelContext.container)
        if let delegate = delegate {
            let defaultPaper = MediaBoxes.getBox(name: userSettings.mediabox)
            pdfUrl = delegate.createPDF(paperSize: defaultPaper)
        }
    }
    
    private func onPrint() async {
        let delegate = await PrintSongDelegate(songID: song.persistentModelID, modelContainer: modelContext.container)
        if let delegate = delegate {
            PrintController.onPrint(title: song.title, delegate: delegate)
        }
    }
}

struct DetailContent: View {
    let song: Song
    var representationHolder: RepresentationHolder

    @Environment(UserSettings.self) private var userSettings

    @State private var darkColor = Color.init(red: 0.25, green: 0.25, blue: 0.25)
    @State private var lightColor = Color.init(red: 0.90, green: 0.90, blue: 0.90)

    var body: some View {
        VStack (alignment: .leading) {
            #if os(macOS)
            Text(song.title).font(.title).fontWeight(.bold).padding(.bottom, 10)
            #endif
            
            ForEach(representationHolder.songRepresentation.sections) { section in
                SectionHeaderView(section: section, lightColor: lightColor, darkColor: darkColor).font(Font(userSettings.headerUIFont))
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                ForEach(section.splittedLines) { line in
                    if (userSettings.hidechords && line.textsIsWhithespaceOrEmpty() && !line.chords.isEmpty) ||
                        (!song.showText && !line.textsIsWhithespaceOrEmpty() && line.chords.isEmpty) ||
                        (!song.showText && userSettings.hidechords && !line.textsIsWhithespaceOrEmpty() && !line.chords.isEmpty) {
                        // bei hidechords sollen alle Zeilen verschwinden und auch kein linespacing machen, die nur chords haben
                        // bei hidetext sollen alle Zeilen verschwinden und auch kein linespacing machen, die nur text haben
                        // bei nix ... ebenso
                        EmptyView()
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            if line.chords.isEmpty && line.textsIsWhithespaceOrEmpty() {
                                // Leerzeile
                                Text(" ").font(Font(userSettings.txtUIFont))
                            } else if userSettings.hidechords {
                                // ist nicht leer
                                if song.showText { Text(line.plainText).font(Font(userSettings.txtUIFont)) }
                            } else {
                                if song.showText {
                                    ChordsLineView(line: line, lightColor: lightColor, darkColor: darkColor).font(Font(userSettings.chordUIFont))
                                    TextsLineView(line: line).font(Font(userSettings.txtUIFont))
                                } else {
                                    ChordsPlainView(line: line, lightColor: lightColor, darkColor: darkColor).font(Font(userSettings.chordUIFont))
                                }
                            }
                        }.padding(EdgeInsets(top: 0, leading: 0, bottom: userSettings.linespacing, trailing: 0))
                    }
                }
            }
        }.padding()
    }
}

struct SectionHeaderView: View {
    let section: CPPSectionSendable
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
                ForEach(line.chords) { chordTxt in
                    HStack(alignment: .center, spacing: 0) {
                        if line.chords.last == chordTxt {
                            Color.clear.frame(width: chordTxt.fontOffset, height: 0.1, alignment: .leading)
                            
                            PopoverButtonView(chordTxt: chordTxt)
                                .lineLimit(1)
                                .padding(.horizontal, 0.8)
                                .background(chordTxt.background ? (colorScheme == .dark ? darkColor : lightColor) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
                        } else {
                            PopoverButtonView(chordTxt: chordTxt)
                                .lineLimit(1)
                                .padding(.horizontal, 0.8)
                                .background(chordTxt.background ? (colorScheme == .dark ? darkColor : lightColor) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
                                .offset(CGSize(width: chordTxt.fontOffset, height: 0))
                        }
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct PopoverButtonView: View {
    let chordTxt: TextElement
    
    @State private var showChordShape: Bool = false

    var body: some View {
        Group {
            if chordTxt.chord != nil {
                Button { showChordShape.toggle() } label: {
                    Text(chordTxt.txt)
                }
            } else {
                Text(chordTxt.txt)
            }
        }
        .popover(isPresented: $showChordShape) {
            /// iOS (nicht iPadOS) bekommt einen exit-Button, da ein ganzes sheet aufgemacht wird
            #if os(macOS)
            ChordDiagramView(chordTxt: chordTxt)
            #else
            if UIDevice.current.userInterfaceIdiom == .pad {
                ChordDiagramView(chordTxt: chordTxt)
            } else {
                VStack {
                    HStack {
                        Spacer()
                        Button(role: .close, action: { showChordShape = false }) {
                            Image(systemName: "checkmark")
                        }
                        .padding()
                    }
                    ChordDiagramView(chordTxt: chordTxt)
                    Spacer()
                }
            }
            #endif
        }
    }
}

struct ChordsPlainView: View {
    let line: SplittedLine
    let lightColor: Color
    let darkColor: Color
    
    @Environment(UserSettings.self) private var userSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if line.chords.isEmpty {
            EmptyView()
        } else {
            HStack(alignment: .center, spacing: 0) {
                ForEach(line.chords) { chord in
                    if chord != line.chords.first { Text(" ").lineLimit(1) }
                        
                    PopoverButtonView(chordTxt: chord)
                        .lineLimit(1)
                        .padding(.horizontal, 0.8)
                        .background(chord.background ? (colorScheme == .dark ? darkColor : lightColor) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
                        .buttonStyle(PlainButtonStyle())
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
