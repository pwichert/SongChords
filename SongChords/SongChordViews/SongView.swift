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
    @State private var uttype: UTType = .pdf
    
    @State private var currentLoop = PlayerLoop(start: 0, stop: 0, title: "")
    @State private var selectedLoop: PlayerLoop?
    @State private var loopActive: Bool = false
    @State private var songSpeed: Double = 1.0
    @State private var songPosition: TimeInterval = 0.0

    var body: some View {
//        let _ = Self._printChanges()

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
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAudioPlayer.toggle()
                        }}) { Label("Audio Player", systemImage: "music.note.list") }
                }
            }
            #endif
            ToolbarItem {
                Button("Edit Song", systemImage: "pencil", action: { pdfUrl = nil; showSongEditView.toggle() }).help("Edit Song")
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
                    AudioPlayerView(song: song, currentLoop: $currentLoop, selectedLoop: $selectedLoop, loopActive: $loopActive, songSpeed: $songSpeed, songPosition: $songPosition)//, playerState: $playerState)
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
        .fileExporter(isPresented: $showFileExport, item: song, contentTypes: [uttype], defaultFilename: Song.makeValidFilename(song.title)) { result in
            switch result {
            case .success(let url):
                print("Gespeichert: \(url)")
            case .failure(let error):
                globals.setSongChordsError(error: error)
            }
        }
        // TODO: in iOS wird .task und .onChange 2x aufgerufen. Daher Schutz davor, solange das nicht geklärt ist.
        .task(id: song.persistentModelID) {
            // wird evtl. gecancelled
            #if os(macOS)
            updateSongRepresentation()
            #else
            if lastID1 != song.persistentModelID {
                updateSongRepresentation()
                lastID1 = song.persistentModelID
            }
            #endif
        }
        .onChange(of: song.persistentModelID, initial: true) {
            // bei Songwechsel auf Livedarstellung schalten
            #if os(macOS)
            songChangedAction()
            #else
            if lastID2 != song.persistentModelID {
                songChangedAction()
                lastID2 = song.persistentModelID
            }
            #endif
        }
        .onChange(of: userSettings.chordsize, initial: false) { print("chordsize changed"); updateSongRepresentation() }
        .onChange(of: userSettings.txtsize, initial: false) { print("txtsize changed"); updateSongRepresentation() }
        .onChange(of: userSettings.headersize, initial: false) { print("headersize changed"); updateSongRepresentation() }
        .onChange(of: userSettings.isGermanNotation, initial: false) { print("isGermanNotation changed"); updateSongRepresentation() }
        .onChange(of: userSettings.textfollowschords, initial: false) { print("textfollowschords changed"); updateSongRepresentation() }
    }
    @State private var lastID1: PersistentIdentifier?
    @State private var lastID2: PersistentIdentifier?

    private func updateSongRepresentation() {
        song.processSongInBackground(userSettings: userSettings, forPrinting: false)
    }
    
    private func songChangedAction() {
        if pdfUrl != nil {
            print("pdfUrl changed")
            pdfUrl = nil
        }
        
        initAudio()
    }
    
    private func initAudio() {
        Task { await timerManager.stopTimer() }
        audioPlayer.stop()
        songSpeed = Double(audioPlayer.songSpeed)
        loopActive = false
        currentLoop = PlayerLoop(start: 0, stop: 0, title: "")
        selectedLoop = nil
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
    var representationHolder: RepresentationHolder

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
