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

    @State private var showAudioPlayer: Bool = false
    @State private var showSongEditView: Bool = false
    @State private var showRemoveAllAnchors: Bool = false
    @State private var showHowtoAutoscroll: Bool = false
    @State private var showFileExport: Bool = false

    @State private var pdfUrl: URL?
    
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var settingsChangeTick = 0
    @State private var autoScrollEnabled = false
    @State private var currentSectionID: Int?
    
    private let darkColor = Color(red: 0.20, green: 0.20, blue: 0.20)
    private let lightColor = Color(red: 0.90, green: 0.90, blue: 0.90)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(userSettings.hidechords ? .vertical : [.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    Spacer()
                        .containerRelativeFrame([.horizontal, .vertical])
                    
                    if let pdfUrl = pdfUrl {
                        PDFKitView(url: pdfUrl)
                        #if os(iOS)
                            .navigationBarTitleDisplayMode(.inline)
                        #endif
                    } else {
                        DetailContent(song: song, darkColor: darkColor, lightColor: lightColor, autoScroll: autoScrollEnabled)
                        #if os(iOS)
                            .navigationBarTitleDisplayMode(.large)
                        #endif
                            .onChange(of: MarkerTimer.shared.time) {
                                let duration = SongTaskManager.shared.representationHolder.directiveManager.duration
                                if duration > 0 && MarkerTimer.shared.time >= TimeInterval(duration) {
                                    print("duration \(duration)")
                                    MarkerTimer.shared.stop()
                                } else {
                                    scrollEvent(proxy: proxy, time: MarkerTimer.shared.time)
                                }
                            }
                            .onChange(of: audioPlayer.position) {
                                scrollEvent(proxy: proxy, time: audioPlayer.position)
                            }
                    }
                }
                .padding(0)
            }
            .overlay(alignment: .topTrailing) {
                if MarkerTimer.shared.isRunning {
                    VStack(alignment: .trailing) {
                        TimerOverlayView(time: MarkerTimer.shared.time, darkColor: darkColor, lightColor: lightColor)
                            .offset(x: -5, y: 5)
                    }
                }
            }
            .scrollPosition($scrollPosition)
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
                    item: SongTransferable(from: song, includeCodable: true, autoScroll: false), preview: SharePreview(Text(song.title), image: Image("AppIconInternal"))
                )
            }
            
            ToolbarItem(placement: .bottomBar) {
                ShareLink(item: SongTransferable(from: song, includePDF: true, autoScroll: autoScrollEnabled), preview: SharePreview(song.title, image: Image("AppIconInternal"))) {
                    Label("Export PDF File", systemImage: "arrow.up.document.fill")
                }
            }
            
            ToolbarSpacer(placement: .bottomBar)
            
            ToolbarItem(placement: .bottomBar) {
                autoScrollMenu
            }
            
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
                autoScrollMenu
            }
            
            ToolbarItem {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAudioPlayer.toggle()
                    }}) { Label("Audio Player", systemImage: "music.note.list").help("Audioplayer") }
            }
            #endif
        }
        .overlay(
            Group {
                if showAudioPlayer {
                    AudioPlayerView(song: song)
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
        .sheet(isPresented: $showHowtoAutoscroll) {
            NavigationStack {
                InfoAutoscrollView()
            }
        }
        .sheet(isPresented: $showSongEditView) {
            NavigationStack {
                if let playlist = song.playlist {
                    SongEditView(playlist: playlist, song: song)
                }
            }
            .interactiveDismissDisabled()
        }
        .alert("Remove all timestamps?", isPresented: $showRemoveAllAnchors) {
            Button("Cancel", role: .cancel) { }
            Button("Ok", role: .destructive) { removeAllAnchors() }
        }
        .fileExporter(isPresented: $showFileExport, item: SongTransferable(from: song, includeCodable: true, includePDF: true, autoScroll: autoScrollEnabled), contentTypes: [], defaultFilename: Song.makeValidFilename(song.title)) { result in
            switch result {
            case .success(let url):
                print("Gespeichert: \(url)")
            case .failure(let error):
                globals.setSongChordsError(error: error)
            }
        }
        .onChange(of: song.persistentModelID, initial: true) {
            settingsChangeTick += 1
            scrollPosition = ScrollPosition(edge: .top)
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
        .onDisappear {
            // Wenn die Playlist gewechselt und ein anderer Song selektiert wird,
            // kann man sonst noch kurz den alten Song sehen
            SongTaskManager.shared.representationHolder.resetRowContent()
        }
    }
    
    var autoScrollMenu: some View {
        Menu {
            if autoScrollEnabled {
                HStack {
                    Button(MarkerTimer.shared.isRunning ? "Stop timer" : "Start timer", systemImage: MarkerTimer.shared.isRunning ? "autostartstop.slash" : "autostartstop", action: {
                        if MarkerTimer.shared.isRunning {
                            MarkerTimer.shared.stop()
                            currentSectionID = nil
                        } else {
                            audioPlayer.stop()
                            MarkerTimer.shared.start()
                        }
                    })
                }
                Button("Autoscroll mode off", systemImage: "rectangle.stack.slash", action: { autoScrollEnabled = false; MarkerTimer.shared.stop() })
                Divider()
                Button("Remove all timestamps", systemImage: "x.square", action: { showRemoveAllAnchors.toggle() }).disabled(song.sectionAnchors.isEmpty)
                
            } else {
                Button("Autoscroll mode on", systemImage: "rectangle.stack", action: {
                    autoScrollEnabled = true
                    syncAnchors()
//                    for s in song.sectionAnchors {
//                        print("\(s.id) \(s.time)")
//                    }
                }).help("Set autoscroll mode on")
            }
            
            Button("How to autoscroll", systemImage: "questionmark.circle", action: { showHowtoAutoscroll.toggle() })
        } label: {
            Label(title: { Text("Autoscroll") },
                  icon: { if autoScrollEnabled { Image(systemName: "rectangle.stack").symbolVariant(.fill) } else { Image(systemName: "rectangle.stack") }}
            )
        }
    }
    
    private func scrollEvent(proxy: ScrollViewProxy, time: TimeInterval) {
        guard autoScrollEnabled else { return }
        
        //print(time)
        if let section = sectionForTime(time, anchors: song.sectionAnchors) {
            if section.id != currentSectionID {
                currentSectionID = section.id
                
                if let rowID = section.headerRowID {
                    withAnimation(.linear(duration: 0.25)) {
                        print("scrollTo \(section.id)")
                        proxy.scrollTo(rowID, anchor: .topLeading)
                    }
                }// else { print("section hat keine headerRowID") }
                
                // bei letzter Section den Timer stoppen, falls die einen anchor hat
                let last = SongTaskManager.shared.representationHolder.sections.sorted(by: { $0.key < $1.key }).last
                if section.id == last?.key {
                    MarkerTimer.shared.stop()
                }
            } //else { print("section nicht geändert") }
        } //else { print("section nicht gefunden") }
    }
        
    private func sectionForTime(_ time: TimeInterval, anchors: [SectionAnchor]) -> SectionModel? {
        if let secId = anchors.sorted(by: { $0.time < $1.time }).last(where: { $0.time <= time })?.id {
            return SongTaskManager.shared.representationHolder.sections[secId]
        }
        
        return nil
    }
    
    private func syncAnchors() {
        print("syncAnchors")
        guard !SongTaskManager.shared.representationHolder.rows.isEmpty else { return }
        
        let anchors = song.sectionAnchors
        for anchor in anchors {
            let section = SongTaskManager.shared.representationHolder.sections[anchor.id]
            if section == nil {
                print("remove anchor \(anchor.id)")
                song.sectionAnchors.removeAll(where: { $0.id == anchor.id })
            }
        }
        do {
            try modelContext.save()
        } catch (let error) {
            globals.setSongChordsError(error: error)
        }
    }

    private func removeAllAnchors() {
        song.sectionAnchors.removeAll()
        
        do {
            try modelContext.save()
        } catch (let error) {
            globals.setSongChordsError(error: error)
        }
    }
    
    private func updateSongRepresentation() {
        Task {
            await SongTaskManager.shared.processSongInBackground(srcText: song.srcText, transpose: song.transpose, showHeader: song.showHeader, showText: song.showText, userSettings: userSettings)
        }
    }
    
    private func songChangedAction() {
        print("songChangedAction")
        
        MarkerTimer.shared.stop()
        currentSectionID = nil
        
        // bei Songwechsel auf Livedarstellung schalten
        if pdfUrl != nil {
            print("pdfUrl changed")
            pdfUrl = nil
        }
    }
    
    private func showPdf() async {
        let delegate = PrintSongDelegate(song: song, autoScroll: autoScrollEnabled)
        pdfUrl = delegate.createPDF()
    }
}

struct DetailContent: View {
    let song: Song
    let darkColor: Color
    let lightColor: Color
    let autoScroll: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(Globals.self) private var globals
    @Environment(AudioPlayer.self) private var audioPlayer

    var body: some View {
//        let _ = Self._printChanges()
//        let _ = print("rendert \(songTitle)")

        let rows = SongTaskManager.shared.representationHolder.rows
        
        VStack(alignment: .leading, spacing: 0) {
            #if os(macOS)
            Text(song.title).font(.title).fontWeight(.bold).padding(.bottom, 10)
            #endif

            // sinnlose rows (wie .sectionEnded) werden in ViewFilter entfernt
            // PDF-Events (.newpage, .columnbreak) werden hier entfernt
            
            ForEach(rows.filter({ return $0.chunkContent != .newpage && $0.chunkContent != .columnbreak })) { rowContent in
                RowView(song: song, modelContext: modelContext, globals: globals, audioPlayer: audioPlayer,
                        darkColor: darkColor, lightColor: lightColor, rowContent: rowContent, forPrinting: false, autoScroll: autoScroll)
            }
        }
        .padding()
    }
}

struct RowView: View, Identifiable {
    let id: UUID = UUID()
    let song: Song
    let modelContext: ModelContext?
    let globals: Globals?
    let audioPlayer: AudioPlayer?
    let darkColor: Color
    let lightColor: Color
    let rowContent: RowContent
    let forPrinting: Bool
    let autoScroll: Bool
    
    @Environment(UserSettings.self) private var userSettings
    
    var body: some View {
//        let _ = Self._printChanges()
//        let _ = print("rendert \(rowContent.id)")
        
        VStack(alignment: .leading, spacing: 0) {
//            let _ = print(rowContent.chunkContent.toString())
            
            switch rowContent.chunkContent {
            case .sectionStarted(let str, let sectionId):
                SectionHeaderView(song: song, modelContext: modelContext, globals: globals, audioPlayer: audioPlayer, autoScroll: autoScroll, sectionId: sectionId, header: str, lightColor: lightColor, darkColor: darkColor).font(Font(forPrinting ? userSettings.headerPDFUIFont : userSettings.headerUIFont))
                
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
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0))
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
    }
}

struct TextsLineView: View, Identifiable {
    let id: UUID = UUID()
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

struct ChordsLineView: View, Identifiable {
    let id: UUID = UUID()
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

struct SectionHeaderView: View, Identifiable {
    let id: UUID = UUID()
    let song: Song
    let modelContext: ModelContext?
    let globals: Globals?
    let audioPlayer: AudioPlayer?
    let autoScroll: Bool
    let sectionId: Int
    let header: String
    let lightColor: Color
    let darkColor: Color
    
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(header + ((autoScroll && sectionInAnchors()) ? (" [" + sectionTime()) + "]" : ""))
                .padding(.leading, 3)
            Spacer()
        }
        .padding(1)
        .background(colorScheme == .dark ? darkColor : lightColor)
        .cornerRadius(5)
        .contextMenu {
            if let modelContext, let globals, autoScroll {
                Button("Set section timestamp") {
                    do {
                        var tm: TimeInterval?
                        if MarkerTimer.shared.isRunning {
                            tm = MarkerTimer.shared.time
                        }
                        else if let audioPlayer {
                            tm = audioPlayer.position
                        }
                        if let tm {
                            saveAnchor(songPosition: tm)
                            try modelContext.save()
                        }
                    } catch (let error) {
                        globals.setSongChordsError(error: error)
                    }
                }
                Divider()
                Button("Remove section timestamp") {
                    do {
                        removeAnchor()
                        try modelContext.save()
                    } catch (let error) {
                        globals.setSongChordsError(error: error)
                    }
                }.disabled(!sectionInAnchors())
            }
        }
    }
    
    func sectionTime() -> String {
        if let anchor = song.sectionAnchors.first(where: { $0.id == sectionId } ) {
            return GlobalFunctions.formatTimeInterval(anchor.time)
        }
        return ""
    }
    
    func sectionInAnchors() -> Bool {
        song.sectionAnchors.first(where: { $0.id == sectionId } ) != nil
    }
    
    func saveAnchor(songPosition: Double) {
        removeAnchor()
        print("hinzugefügt section \(sectionId) an position \(Int(songPosition))")
        song.sectionAnchors.append(SectionAnchor(id: sectionId, time: songPosition))
    }

    func removeAnchor() {
        if sectionInAnchors() {
            print("entferne section \(sectionId)")
            song.sectionAnchors.removeAll(where: { $0.id == sectionId })
        }
    }
}

struct ChordsPlainView: View, Identifiable {
    let id: UUID = UUID()
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

struct PopoverButtonView: View, Identifiable {
    let id: UUID = UUID()
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

struct TimerOverlayView: View {
    let time: TimeInterval
    let darkColor: Color
    let lightColor: Color

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(String(GlobalFunctions.formatTimeInterval(time)))
            .font(.headline)
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(colorScheme == .dark ? darkColor : lightColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(radius: 3)
    }
}

struct InfoAutoscrollView: View {
    var body: some View {
        InfoContentView("Autoscroll") {
            Text("How To Autoscroll")
        }
    }
}
