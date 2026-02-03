//
//  AudioPlayerView.swift
//  SongChords
//
//  Created by Peter Wichert on 21.01.25.
//

import SwiftUI
import MusicKit

struct MusicItem: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let artWork: Artwork?
}

struct AudioPlayerView: View {
    let song: Song
    
    @State private var showSongSearch: Bool = false
    @State private var showMP3Import: Bool = false
    @State private var showNoAppleMusic: Bool = false
    @State private var showSmallView: Bool = false

    @State private var currentLoop = PlayerLoop(start: 0, stop: 0, title: "")
    @State private var selectedLoop: PlayerLoop?
    @State private var loopActive: Bool = false
    
    @State private var songSpeed: Float = 1
    @State private var songPitch: Float = 0
    
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(Globals.self) private var globals
    @Environment(\.modelContext) private var modelContext

    #if os(macOS)
    let gridVerticalSpacing = 6.0
    #else
    let gridVerticalSpacing = 1.0
    #endif
    
    var body: some View {
        VStack {
            VStack {
                if !showSmallView {
                    PlayerLoopEditView(song: song, currentLoop: $currentLoop, active: $loopActive)
                        .lineLimit(1)
                    
                    List(selection: $selectedLoop) {
                        ForEach(song.playerLoops.sorted(by: { $0.start == $1.start ? $0.stop < $1.stop : $0.start < $1.start }), id: \.self) { playerLoop in
                            HStack {
                                Text(playerLoop.title.isEmpty ? "-" : playerLoop.title)
                                Spacer()
                                Text(GlobalFunctions.formatTimeInterval(playerLoop.stop - playerLoop.start))
                            }
                            #if os(iOS)
                            .font(.footnote).listRowInsets(.init(top: 8, leading: 8, bottom: 8, trailing: 8))
                            #else
                            .font(.subheadline)
                            #endif
                            .foregroundStyle(!audioPlayer.isLoaded || audioPlayer.isValidLoop(loop: playerLoop) ? Color.primary : Color.red)
                        }
                        .onDelete(perform: { indices in
                            var idxSet = Set<UUID>()
                            for index in indices { idxSet.insert(song.playerLoops.sorted(by: { $0.start == $1.start ? $0.stop < $1.stop : $0.start < $1.start })[index].id )}
                            for index in idxSet { song.playerLoops.removeAll(where: { $0.id == index })}
                            
                            do {
                                try modelContext.save()
                            } catch (let error) {
                                globals.setSongChordsError(error: error)
                            }
                        } )
                    }
                    #if os(iOS)
                    .environment(\.defaultMinListRowHeight, 10)
                    #endif
                    .frame(maxHeight: 150).cornerRadius(10)
                    .overlay( /// apply a rounded border
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.secondary, lineWidth: 1)
                    )
                }
            }
            
            playbackButtonsView
            
            if !showSmallView {
                Grid(alignment: .trailing, verticalSpacing: 0) {
                    PositionGridRow(song: song)
                    .padding(.bottom, gridVerticalSpacing * 1.5)
                    GridRow(alignment: .center) {
                        Text("Speed")
                        Slider(
                            value: $songSpeed,       // durch Schattenvariable Scrubbing verhindern
                            in: 0.3...1,
                            onEditingChanged: { editing in
                                if !editing { audioPlayer.rate = songSpeed }
                            }
                        ).disabled(GlobalFunctions.isDisabled(song: song))
                        Text("\(Int(round(songSpeed * 100.0)))%").font(.footnote).frame(width: 50).lineLimit(1)
                    }.padding(.bottom, gridVerticalSpacing)
                    
                    if song.isLocalMP3() {
                        GridRow(alignment: .center) {
                            Text("Pitch")
                            HStack {
                                Slider(
                                    value: $songPitch,      // durch Schattenvariable Scrubbing verhindern
                                    in: -110...110,
                                    onEditingChanged: { editing in
                                        if !editing {
                                            audioPlayer.pitch = songPitch
                                            setSongPitch(songPitch)
                                        }
                                    }
                                ).disabled(!song.isLocalMP3() || GlobalFunctions.isDisabled(song: song))
                                HStack {
                                    Button(action: { songPitch = nextDown(val: songPitch); audioPlayer.pitch = songPitch; setSongPitch(songPitch) }) {
                                        Image(systemName: "minus.circle").font(.title3)
                                    }.disabled(GlobalFunctions.isDisabled(song: song))
                                    Button(action: { songPitch = nextUp(val: songPitch); audioPlayer.pitch = songPitch; setSongPitch(songPitch) }) {
                                        Image(systemName: "plus.circle").font(.title3)
                                    }.disabled(GlobalFunctions.isDisabled(song: song))
                                }
                            }
                            Text(String(format: "%.2f", songPitch / 10.0)).font(.footnote).frame(width: 50).lineLimit(1)
                        }.padding(.bottom, gridVerticalSpacing)
                    }
                }
                .padding(.horizontal)
                .font(.footnote)
            }
            
            ZStack {
                if !showSmallView {
                    HStack {
                        Spacer()
                        Button(action: {
                            Task {
                                do {
                                    try await checkAppleMusicAvailability()
                                    showSongSearch.toggle()
                                } catch {
                                    globals.setSongChordsError(error: error)
                                }
                            }
                        } ) {
                            Label("Search Apple Music", systemImage: "music.note.list")
                        }.buttonStyle(BorderedButtonStyle()).font(.footnote)
                        
                        Button(action: { showMP3Import.toggle() } ) {
                            Label("Import MP3 File", systemImage: "document")
                        }.buttonStyle(BorderedButtonStyle()).font(.footnote)
                        
                        Spacer()
                        Button(action: { showSmallView.toggle() }) {
                            Image(systemName: showSmallView ? "chevron.up.circle" : "chevron.down.circle").font(.body).bold().labelStyle(.iconOnly)
                        }.buttonStyle(BorderedButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: 500)
        .sheet(isPresented: $showSongSearch) {
            NavigationStack {
                MusicContentView(song: song)
            }
        }
        .fileImporter(isPresented: $showMP3Import, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                importMP3File(song: song, urls: urls)
                do {
                    try modelContext.save()
                } catch(let error) {
                    globals.setSongChordsError(error: error)
                }
            case .failure(let error):
                globals.setSongChordsError(error: error)
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
        .onChange(of: song.persistentModelID, initial: true) {
            audioPlayer.stop()
            audioPlayer.setDefaults()
                        
            if song.musicItemId.starts(with: "local@") {
                do {
                    let (_, pitch) = try song.getMP3Info()
                    audioPlayer.pitch = pitch
                } catch (let error) {
                    print(error.localizedDescription)
                }
            }
            
            currentLoop = PlayerLoop(start: 0, stop: 0, title: "")
            loopActive = false
            selectedLoop = nil
        }
        .onChange(of: audioPlayer.pitch) { _, newValue in
            songPitch = newValue
        }
        .onChange(of: audioPlayer.rate) { _, newValue in
            songSpeed = newValue
        }
        // Loop selektiert
        .onChange(of: selectedLoop) {
//            print("change selectedLoop")
            if let selectedLoop {
                currentLoop = PlayerLoop(start: selectedLoop.start, stop: selectedLoop.stop, title: selectedLoop.title)
                if loopActive { audioPlayer.loop = currentLoop }
            }
        }
        // loopActive gedrückt
        .onChange(of: loopActive) { _, active in
//            print("change loopActive \(active)")
            if active {
                audioPlayer.loop = currentLoop
            } else {
                audioPlayer.loop = nil
            }
        }
    }
    
    private var playbackButtonsView: some View {
        HStack {
            Spacer()
            Button(action: { rewindPlayback() }) {
                HStack(alignment: .center, spacing: 1) {
                    Label("rewind", systemImage: "play.fill").rotationEffect(.degrees(180)).labelStyle(.iconOnly)
                    Label("rewind", systemImage: "play.fill").rotationEffect(.degrees(180)).labelStyle(.iconOnly)
                }.padding(.horizontal)
            }.disabled(GlobalFunctions.isDisabled(song: song))
            
            Button(action: { Task {
                do {
                    try await startPlayback()
                } catch (let error) { globals.setSongChordsError(error: error) }
            }}
            ){
                HStack(alignment: .center, spacing: nil) {
                    if audioPlayer.state == .loading {
                        ProgressView().progressViewStyle(.circular).controlSize(.mini)
                    } else {
                        audioPlayer.state == .playing ? Image(systemName: "pause.fill") : Image(systemName: "play.fill")
                    }
                    Text(audioPlayer.state == .playing ? "Pause" : "Play")
                }.frame(minWidth: 70) // hält die Buttonbreite konstant, wenn sich Texte Pause/Play ändern
            }.disabled(GlobalFunctions.isDisabled(song: song))// || shouldOfferSubscription)
            
            Button(action: { audioPlayer.stop()  }) {
                Label("Stop", systemImage: "stop.fill")
            }.disabled(GlobalFunctions.isDisabled(song: song))
            
            Spacer()
            if showSmallView {
                Button(action: { showSmallView.toggle() }) {
                    Image(systemName: showSmallView ? "chevron.up.circle" : "chevron.down.circle").font(.body).bold().labelStyle(.iconOnly)
                }
            }
        }.buttonStyle(BorderedButtonStyle()).font(.footnote)
    }
    
    private var smallLargeToggleView: some View {
        HStack {
            Spacer()
            Button(action: { showSmallView.toggle() }) { Label("", systemImage: showSmallView ? "chevron.up.circle" : "chevron.down.circle").font(.body).bold().labelStyle(.iconOnly) }
                .buttonStyle(BorderedButtonStyle())
        }
    }
    
    private func checkAppleMusicAvailability() async throws {
        let auth = await MusicAuthorization.request()
        guard auth == .authorized else { throw PlayerError.noAppleMusic }
        
        let subscription = try await MusicSubscription.current
        guard subscription.canPlayCatalogContent else { throw PlayerError.noAppleMusicSubscription }
    }
    
    private func nextUp(val: Float) -> Float {
        let val10 = Int(round(val * 10.0))
        let x = val10 % 5 == 0 ? 5 : (5 - val10 % 5)
        return (Float(val10 + x) / 10.0)
    }
    
    private func nextDown(val: Float) -> Float {
        let val10 = Int(round(val * 10.0))
        let x = val10 % 5 == 0 ? 5 : val10 % 5
        return (Float(val10 - x) / 10.0)
    }
    
    private func startPlayback() async throws {
        if audioPlayer.state == .playing {
            audioPlayer.pause()
        } else {
            // falls Fehler auftritt, Spinner weg
            do {
                if !audioPlayer.isLoaded {
                    try await audioPlayer.load(song: song)
                }
                try await audioPlayer.play()
            } catch (let error) { throw error }            
        }
    }
    
    private func rewindPlayback() {
        if loopActive {
            audioPlayer.position = currentLoop.start
        } else {
            audioPlayer.position = 0
        }
    }
    
    private func setSongPitch(_ pitch: Float) {
        do {
            let (uuidStr, _) = try song.getMP3Info()
            song.setMP3Info(uuid: uuidStr, pitch: pitch)
            try modelContext.save()
        } catch(let error) {
            globals.setSongChordsError(error: error)
        }
    }
    
    private func importMP3File(song: Song, urls: [URL]) {
        do {
            audioPlayer.stop()
            
            let fileManager = FileManager.default
            let destDir = try GlobalFunctions.mp3Path()
            
            for url in urls {
                print("Lade \(url.absoluteString)")
                
                guard url.pathExtension.lowercased() == "mp3" else { continue }
                
                var uuid = UUID().uuidString
                var pitch: Float = 0.0
                
                do {
                    (uuid, pitch) = try song.getMP3Info()
                    song.tryRemoveMP3()
                } catch {}
                
                let destURL = destDir
                    .appendingPathComponent(uuid + ".mp3")
                
                let startSecurityScope = url.startAccessingSecurityScopedResource()
                try fileManager.copyItem(at: url, to: destURL)
                if startSecurityScope { url.stopAccessingSecurityScopedResource() }
                
                song.setMP3Info(uuid: uuid, pitch: pitch)
                print("\(song.musicItemId)")
                
                break
            }
        } catch(let error) {
            print("Fehler beim mp3-Laden: \(error.localizedDescription)")
            globals.setSongChordsError(error: error)
        }
    }
}

struct PositionGridRow: View {
    let song: Song
    
    @State private var inPositionEditing: Bool = false
    @State private var songPosition: TimeInterval = 0
    
    @Environment(AudioPlayer.self) private var audioPlayer

    var body: some View {
        GridRow(alignment: .center) {
            Text("Pos")
            #if os(macOS)
            Slider(
                value: $songPosition,       // durch Schattenvariable Scrubbing verhindern
                in: 0...audioPlayer.duration,
                onEditingChanged: { editing in
                    inPositionEditing = editing
                }
            )
            .disabled(GlobalFunctions.isDisabled(song: song))
            #else
            Slider(
                value: $songPosition,       // durch Schattenvariable Scrubbing verhindern
                in: 0...audioPlayer.duration
            )
            .simultaneousGesture (      // onEditingChanged geht manchmal verloren, Gesture ist sicherer
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !inPositionEditing {
                            inPositionEditing = true
                        }
                    }
                    .onEnded { _ in
                        inPositionEditing = false
                    }
            )
            .disabled(GlobalFunctions.isDisabled(song: song))
            #endif
            Text(GlobalFunctions.formatTimeInterval(songPosition)).font(.footnote).frame(width: 50).lineLimit(1)
        }
        // Kopplung zwischen audioPlayer.position und songPosition
        // außer bei inPositionEditing == true, wenn also der Slider bewegt wird.
        // Scrubbing verhindern durch Kopie für Slider in $songPosition und nicht direkt auf audioPlayer.position
        .onChange(of: audioPlayer.position) { _, newValue in
//            print("position changed \(newValue)")
            if !inPositionEditing { songPosition = newValue }
        }
        .onChange(of: inPositionEditing) {
//            print("change inPositionEditing \(inPositionEditing)")
            if !inPositionEditing { audioPlayer.position = songPosition }
        }
    }
}

struct MusicContentView: View {
    let song: Song
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(Globals.self) private var globals

    // MARK: - View
    
    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.gray)
                TextField("Search...", text: $searchTerm)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            
            if let item = selectedSong ?? songMusicItem {
                HStack {
                    if let artwork = item.artWork {
                        ArtworkImage(artwork, width: 80)
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading) {
                        Text(item.artistName).font(.headline)
                        Text(item.title).font(.caption)
                    }
                    Spacer()
                }.padding()
            } else {
                Text("No song assigned").font(.headline).padding()
            }
            
            searchResultsList
                .animation(.default, value: songs)
        }
        .frame(maxWidth: 500, idealHeight: 500)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Ok", systemImage: "checkmark", role: .confirm) {
                    Task {
                        do {
                            let id = String(selectedSong?.id ?? "")
                            song.tryRemoveMP3() // falls schon MP3 geladen wurde, erst löschen
                            song.musicItemId = id
                            try modelContext.save()
                        } catch (let error) {
                            globals.setSongChordsError(error: error)
                        }
                    }
                    dismiss()
                }.disabled(selectedSong == nil)
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark", role: .cancel) {
                    dismiss()
                }
            }
        }
        .navigationTitle("Apple Music Search")
        .onChange(of: searchTerm) { requestUpdatedSearchResults(for: searchTerm) }
        .onAppear {
            searchTerm = song.title
            requestSearchID(for: song.musicItemId)
        }
    }
    
    /// The various components of the main navigation view.
    private var navigationViewContents: some View {
        VStack {
            searchResultsList
                .animation(.default, value: songs)
        }
    }
    
    /// The top-level content view.
    private var rootView: some View {
        NavigationView {
            navigationViewContents
                .navigationTitle("Apple Music Search")
        }
        .searchable(text: $searchTerm, prompt: "Search...")
    }
    
    // MARK: - Search results requesting
    
    /// The current search term the user enters.
    @State private var searchTerm = ""
    
    /// The albums the app loads using MusicKit that match the current search term.
    @State private var songs: [MusicItem] = []
    @State private var selectedSong: MusicItem?
    @State private var songMusicItem: MusicItem?

    /// A list of albums to display below the search bar.
    private var searchResultsList: some View {
        List(songs, id: \.self, selection: $selectedSong) { musicItem in
            HStack {
                if let artwork = musicItem.artWork {
                    ArtworkImage(artwork, width: 60)
                        .cornerRadius(3)
                }
                VStack(alignment: .leading) {
                    Text(musicItem.artistName).font(.headline)
                    Text(musicItem.title).font(.caption)
                }
            }
        }
    }
    
    /// Makes a new search request to MusicKit when the current search term changes.
    private func requestUpdatedSearchResults(for searchTerm: String) {
        Task.detached {
            if searchTerm.isEmpty {
                await self.reset()
            } else {
                do {
                    // Issue a catalog search request for albums matching the search term.
                    var searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [MusicKit.Song.self])
                    searchRequest.limit = 8
                    let searchResponse = try await searchRequest.response().songs.compactMap { song in
                        MusicItem(
                            id: song.id.rawValue,
                            title: song.title,
                            artistName: song.artistName,
                            artWork: song.artwork
                        )
                    }
                    
                    // Update the user interface with the search response.
                    await self.apply(searchResponse, for: searchTerm)
                } catch {
                    print("Search request failed with error: \(error).")
                    await self.reset()
                }
            }
        }
    }
    
    private func requestSearchID(for searchID: String) {
        Task.detached {
            if searchID.isEmpty {
            } else {
                do {
                    // Issue a catalog search request for albums matching the search term.
                    var searchRequest = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(searchID))
                    searchRequest.limit = 1
                    let searchResponse = try await searchRequest.response().items.map { song in
                        MusicItem(
                            id: song.id.rawValue,
                            title: song.title,
                            artistName: song.artistName,
                            artWork: song.artwork
                        )
                    }
                    
                    // Update the user interface with the search response.
                    if let searchResponse = searchResponse.first {
                        await self.applySong(searchResponse, for: searchTerm)
                    }
                } catch {
                    print("Search request failed with error: \(error).")
                }
            }
        }
    }
    
    /// Safely updates the `albums` property on the main thread.
    private func applySong(_ searchResponse: MusicItem, for searchTerm: String) {
        if self.searchTerm == searchTerm {
            self.songMusicItem = searchResponse
        }
    }
    
    /// Safely updates the `albums` property on the main thread.
    private func apply(_ searchResponse: [MusicItem], for searchTerm: String) {
        if self.searchTerm == searchTerm {
            self.songs = searchResponse
        }
    }
    
    /// Safely resets the `albums` property on the main thread.
    private func reset() {
        self.songs = []
    }
}

struct PlayerLoopEditView: View {
    let song: Song
    @Binding var currentLoop: PlayerLoop
    @Binding var active: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Environment(Globals.self) private var globals
    @Environment(AudioPlayer.self) private var audioPlayer

    var body: some View {
        HStack(alignment: .center) {
            VStack {
                Text("Active").font(.footnote)
                Button {
                    active.toggle()
                } label: {
                    Image(systemName: active ? "checkmark.square" : "square").font(.title)
                }
                .disabled(GlobalFunctions.isDisabled(song: song))
                Text("").font(.footnote)
            }
            
            TextField("Looptitle", text: $currentLoop.title)
                .autocorrectionDisabled(true)
                .disabled(song.musicItemId.isEmpty)
                .font(.body)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .foregroundStyle(!audioPlayer.isLoaded || audioPlayer.isValidLoop(loop: currentLoop) ? Color.primary : Color.red)
            SetButtonView(song: song, txt: "Start", point: $currentLoop.start)
            SetButtonView(song: song, txt: "End", point: $currentLoop.stop)
            
            VStack {
                Text("Save").font(.footnote)
                Button {
                    saveToList()
                } label: {
                    Image(systemName: "square.and.arrow.down").font(.title)
                }
                .disabled(GlobalFunctions.isDisabled(song: song) || !audioPlayer.isValidLoop(loop: currentLoop))
                Text("").font(.footnote)
            }
        }
    }

    private func saveToList() {
        // currentLoop in song.playerLoops suchen
        // wenn gefunden, dann updaten
        let list = song.playerLoops
        let loopTitle = currentLoop.title.trimmingCharacters(in: .whitespaces)
        if !loopTitle.isEmpty, let listIndex = list.firstIndex(where: { $0.title.trimmingCharacters(in: .whitespaces) == loopTitle }) {
            list[listIndex].start = currentLoop.start
            list[listIndex].stop = currentLoop.stop
            list[listIndex].title = loopTitle
            song.playerLoops = list
        } else {
            // wenn nicht gefunden, dann currentLoop neu hinzufügen
            song.playerLoops.append(PlayerLoop(start: currentLoop.start, stop: currentLoop.stop, title: loopTitle.isEmpty ? "Loop \(song.playerLoops.count)" : loopTitle))
        }
                
        do {
            try modelContext.save()
        } catch (let error) {
            globals.setSongChordsError(error: error)
            print("Fehler beim Speichern: \(error.localizedDescription)")
        }
    }
}

struct SetButtonView: View {
    let song: Song
    let txt: String
    @Binding var point: TimeInterval

    @Environment(AudioPlayer.self) private var audioPlayer

    var body: some View {
        VStack(alignment: .center) {
            Text(txt).font(.footnote)
            Button { point = audioPlayer.enginePosition } label: { Image(systemName: "button.programmable").font(.title) }.disabled(GlobalFunctions.isDisabled(song: song))
            Text(GlobalFunctions.formatTimeInterval(point)).font(.footnote)
        }
    }
}
