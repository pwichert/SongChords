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
    let songID: PersistentIdentifier
    @Binding var visibility: NavigationSplitViewVisibility

    @Query private var songs: [Song]

    init(songID: PersistentIdentifier, visibility: Binding<NavigationSplitViewVisibility>) {
        self.songID = songID
        self._visibility = visibility
        
        _songs = Query(
            filter: #Predicate<Song> {
                $0.persistentModelID == songID
            }
        )
    }
    
    var body: some View {
        if let song = songs.first {
            SongViewX(song: song, visibility: $visibility)
        } else {
            ContentUnavailableView("Select a song", systemImage: "doc.text.image.fill")
        }
    }
}

internal struct SongViewX: View {
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

    @State private var settingsChangeTick = 0

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
                        DetailContent(songTitle: song.title)
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
        .onChange(of: song.persistentModelID, initial: true) {
            settingsChangeTick += 1
            songChangedAction()
        }
        .onChange(of: song.showText, initial: false) { print("showtext changed"); settingsChangeTick += 1 }
        .onChange(of: userSettings.hidechords, initial: false) { print("hidechords changed"); settingsChangeTick += 1 }
        .onChange(of: userSettings.chordsize, initial: false) { print("chordsize changed"); settingsChangeTick += 1 }
        .onChange(of: userSettings.txtsize, initial: false) { print("txtsize changed"); settingsChangeTick += 1 }
        .onChange(of: userSettings.headersize, initial: false) { print("headersize changed"); settingsChangeTick += 1 }
        .onChange(of: userSettings.isGermanNotation, initial: false) { print("isGermanNotation changed"); settingsChangeTick += 1 }
        .onChange(of: userSettings.textfollowschords, initial: false) { print("textfollowschords changed"); settingsChangeTick += 1 }
        .onChange(of: settingsChangeTick) {
            updateSongRepresentation()
        }
    }
    
    private func updateSongRepresentation() {
        Task {
            await SongTaskManager.shared.processSongInBackground(srcText: song.srcText, transpose: song.transpose, showHeader: song.showHeader, showText: song.showText, userSettings: userSettings)
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
}

struct DetailContent: View {
    let songTitle: String
        
    private let darkColor = Color(red: 0.25, green: 0.25, blue: 0.25)
    private let lightColor = Color(red: 0.90, green: 0.90, blue: 0.90)

    var body: some View {
//        let _ = Self._printChanges()
//        let _ = print("rendert \(songTitle)")

        let rows = SongTaskManager.shared.representationHolder.rows
        
        VStack(alignment: .leading) {
            #if os(macOS)
            Text(songTitle).font(.title).fontWeight(.bold).padding(.bottom, 10)
            #endif

            ForEach(rows.filter({ return $0.content != SongRenderChunk.chunkContent.newpage && $0.content != SongRenderChunk.chunkContent.columnbreak })) { row in
                RowView(id: row.id, darkColor: darkColor, lightColor: lightColor, model: row, rowEvents: [], forPrinting: false)
            }
        }
        .padding()
    }
}

struct RowView: View, Identifiable {
    let id: Int
    let darkColor: Color
    let lightColor: Color
    let model: RenderRowModel
    let rowEvents: [() -> Void]
    let forPrinting: Bool
    
    @Environment(UserSettings.self) private var userSettings
    
    var body: some View {
//        let _ = Self._printChanges()
//        let _ = print("rendert \(model.id)")
        
        VStack(alignment: .leading, spacing: 0) {
//            let _ = print(model.content.toString())
            
            switch model.content {
            case .sectionStarted(let str):
                SectionHeaderView(header: str, lightColor: lightColor, darkColor: darkColor).font(Font(forPrinting ? userSettings.headerPDFUIFont : userSettings.headerUIFont))
                
            case .chordline(let line):
                ChordsLineView(line: line, lightColor: lightColor, darkColor: darkColor).font(Font(forPrinting ? userSettings.chordPDFUIFont : userSettings.chordUIFont))
                
            case .chordplainline(let line):
                ChordsPlainView(line: line, lightColor: lightColor, darkColor: darkColor).font(Font(forPrinting ? userSettings.chordPDFUIFont : userSettings.chordUIFont))
                
            case .textline(let line, _):
                TextsLineView(line: line).font(Font(forPrinting ? userSettings.txtPDFUIFont : userSettings.txtUIFont))
                
            case .textplainline(let line):
                Text(line).font(Font(forPrinting ? userSettings.txtPDFUIFont : userSettings.txtUIFont))
                                
            case .splittedline(chords: let chords, texts: let texts, _):
                ChordsLineView(line: chords, lightColor: lightColor, darkColor: darkColor).font(Font(forPrinting ? userSettings.chordPDFUIFont : userSettings.chordUIFont))
                TextsLineView(line: texts).font(Font(forPrinting ? userSettings.txtPDFUIFont : userSettings.txtUIFont))
                
            case .emptyline:
                Text(" ").font(Font(forPrinting ? userSettings.txtPDFUIFont : userSettings.txtUIFont))
                
            case .columnbreak, .newpage:
                // in DetailView entfernt
                // Color.clear.frame(width: 1, height: 1, alignment: .center)
                EmptyView()

            case .sectionEnded:
                // in ViewFilter entfernt
                // Color.clear.frame(width: 1, height: 1, alignment: .center)
                EmptyView()
            }
        }.padding(EdgeInsets(top: 0, leading: 0, bottom: forPrinting ? userSettings.linespacingpdf : userSettings.linespacing, trailing: 0))
        .onAppear {
            for f in rowEvents { f() }
        }
    }
}

struct TextsLineView: View {
    let line: [TextElement]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(line) { text in
                HStack(alignment: .center, spacing: 0) {
                    if line.last == text {
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

struct ChordsLineView: View {
    let line: [TextElement]
    let lightColor: Color
    let darkColor: Color
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(line) { chordTxt in
                HStack(alignment: .center, spacing: 0) {
                    if line.last == chordTxt {
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

struct SectionHeaderView: View {
    let header: String
    let lightColor: Color
    let darkColor: Color
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .center) {
            Text(header)
                .padding(.leading, 3)
            Spacer()
        }
        .padding(1)
        .background(colorScheme == .dark ? darkColor : lightColor)
        .cornerRadius(5)
    }
}

struct ChordsPlainView: View {
    let line: [TextElement]
    let lightColor: Color
    let darkColor: Color
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(line) { chord in
                if chord != line.first { Text(" ").lineLimit(1) }
                
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
