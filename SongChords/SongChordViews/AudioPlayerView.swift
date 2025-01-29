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

enum PlaybackStatus {
    case playing
    case paused
    case stopped
}

struct AudioPlayerView: View {
    @Bindable var song: Song
    @Binding var currentLoop: PlayerLoop
    @Binding var selectedLoop: PlayerLoop?
    @Binding var loopActive: Bool
    @Binding var songSpeed: Double
    @Binding var songPosition: TimeInterval
    @Binding var playerState: PlaybackStatus
    
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(Globals.self) private var globals
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var loopTimerManager

    @State private var showSongSearch: Bool = false
            
    // aktualisiert den Status des AudioPlayers, insb. die Position
    let statusTimer = Timer.publish(every: 1, tolerance: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            if !audioPlayer.isAllowed {
                AudioPlayerNotAllowedView().padding()
            } else {
                #if DEBUG || os(iOS)
                VStack {
                    PlayerLoopEditView(song: song, currentLoop: $currentLoop, active: $loopActive)
                        .lineLimit(1)
                    
                    List(selection: $selectedLoop) {
                        ForEach(song.playerLoops.sorted(by: { $0.start < $1.start }), id: \.self) { playerLoop in
                            Text(playerLoop.title.isEmpty ? "-" : playerLoop.title).font(.subheadline)
                        }
                        .onDelete(perform: { indices in
                            var idxSet = Set<UUID>()
                            for index in indices { idxSet.insert(song.playerLoops.sorted(by: { $0.start < $1.start })[index].id )}
                            for index in idxSet { song.playerLoops.removeAll(where: { $0.id == index })}

                            do {
                                try modelContext.save()
                            } catch (let error) {
                                globals.setSongChordsError(error: error)
                            }
                        } )
                    }
                    .frame(maxHeight: 200).cornerRadius(10)
                    .overlay( /// apply a rounded border
                        RoundedRectangle(cornerRadius: 10)
                        .stroke(.secondary, lineWidth: 1)
                    )
                }
                #endif

                HStack {
                    Button(action: { startPlayback() }) {
                        playerState == .playing ? Label("Pause", systemImage: "pause.fill") : Label("Play", systemImage: "play.fill")
                    }.disabled(song.musicItemId.isEmpty)
                    Button(action: { stopPlayback() }) {
                        Label("Stop", systemImage: "stop.fill")
                    }.disabled(song.musicItemId.isEmpty)
                    Button(action: { showSongSearch.toggle() } ) {
                        Label("Select Song", systemImage: "music.note.list")
                    }.lineLimit(1)
                }.buttonStyle(BorderedButtonStyle()).font(.footnote)
                
                Grid(alignment: .trailing) {
                    #if DEBUG || os(iOS)
                    GridRow {
                        Text("Pos")
                        Slider(value: $songPosition, in: 0...1.0, step: 0.01, onEditingChanged: { editing in
                            if !editing { audioPlayer.songPosition = songPosition * audioPlayer.songDuration }
                        }).disabled(song.musicItemId.isEmpty)
                        Text(formatTimeInterval(songPosition * audioPlayer.songDuration)).font(.footnote).frame(width: 50).lineLimit(1)
                    }
                    #endif
                    GridRow {
                        Text("Speed")
                        Slider(value: $songSpeed, in: 0.3...1.0, step: 0.01, onEditingChanged: { editing in
                            if !editing { audioPlayer.songSpeed = Float(songSpeed); setCurrentLoopTimer() }
                        }).disabled(song.musicItemId.isEmpty)
                        Text(String(format: "%.0f%%", songSpeed * 100.0)).font(.footnote).frame(width: 50).lineLimit(1)
                    }
                }
                .font(.footnote)
                .padding()
            }
        }
        .frame(maxWidth: 500)
        .sheet(isPresented: $showSongSearch) {
            NavigationStack {
                MusicContentView(song: song)
            }
        }
        .onChange(of: loopActive, initial: false) {
            setCurrentLoopTimer()
        }
        .onChange(of: selectedLoop, initial: false) {
            if let selectedLoop {
                // currentLoop übernimmt die Werte der Auswahl in neuem Objekt, nicht das Objekt selbst
                currentLoop = PlayerLoop(start: selectedLoop.start, stop: selectedLoop.stop, title: selectedLoop.title)
            }
            setCurrentLoopTimer()
        }
        .onChange(of: audioPlayer.playerState, initial: true) { oldState, newState in
            // Status aktualisieren
//            print("change \(oldState) \(newState)")
            
            // Merkwürdiges Verhalten
            
//            switch newState {
//            case .paused: playerState = .paused
//            case .stopped: playerState = .stopped
//            case .playing: playerState = .playing
//            case .interrupted, .seekingForward, .seekingBackward: playerState = .stopped
//            @unknown default:
//                playerState = .stopped
//            }
        }
        .onReceive(statusTimer) { time in
            // Songfortschritt anzeigen
//            print("statusTimer: time \(time) state \(audioPlayer.playerState) position \(audioPlayer.songPosition)")
            songPosition = audioPlayer.songDuration == 0 ? 0 : audioPlayer.songPosition / audioPlayer.songDuration
        }
    }

    private func startLoopTimer(interval: TimeInterval) {
        Task {
            await loopTimerManager.startTimer(interval: interval / Double(audioPlayer.songSpeed), task: {
                Task { await fireLoopTimer() }
            } )
        }
    }
    
    private func resumeLoopTimer(remainingInterval: TimeInterval, normalInterval: TimeInterval) {
        Task {
            await loopTimerManager.resumeTimer(remainingInterval: remainingInterval / Double(audioPlayer.songSpeed), normalInterval: normalInterval / Double(audioPlayer.songSpeed), task: {
                Task { await fireLoopTimer() }
            } )
        }
    }
    
    private func fireLoopTimer() {
        print("loopTimer ended, position set to \(currentLoop.start)")
        audioPlayer.songPosition = currentLoop.start
    }
    
    private func stopLoopTimer() {
        Task {
            await loopTimerManager.stopTimer()
        }
    }
    
    private func setCurrentLoopTimer() {
        audioPlayer.load(id: song.musicItemId)

        if loopActive {
            if audioPlayer.songPosition <= currentLoop.start || audioPlayer.songPosition >= currentLoop.stop {
                audioPlayer.songPosition = currentLoop.start
                if playerState == .playing { startLoopTimer(interval: currentLoop.stop - currentLoop.start) }
            } else {
                let rest = currentLoop.stop - audioPlayer.songPosition
                if playerState == .playing { resumeLoopTimer(remainingInterval: rest, normalInterval: currentLoop.stop - currentLoop.start)}
            }
        } else {
            stopLoopTimer()
        }
    }
    
    private func startPlayback() {
        // Das Setzen des State verhindert die Verzögerungen des "echten" State
        let plState = playerState
        
        if plState == .playing {
            audioPlayer.pause()
            stopLoopTimer()
            playerState = .paused
        } else {
            audioPlayer.loadAndPlay(id: song.musicItemId)
            playerState = .playing
            setCurrentLoopTimer()
        }
    }

    private func stopPlayback() {
        playerState = .stopped
        audioPlayer.stop()
        stopLoopTimer()
    }

    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: timeInterval) ?? "00:00"
    }
}

struct AudioPlayerNotAllowedView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    var body: some View {
        Text("Audio playback is not allowed in this app")
            .onAppear {
                audioPlayer.handleAuthorizationStatus()
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
                Button(action: {
                    do {
                        let id = String(selectedSong?.id ?? "")
                        song.musicItemId = id
                        try modelContext.save()
                    } catch (let error) {
                        globals.setSongChordsError(error: error)
                    }
                    dismiss()
                }) {
                    Text("Ok")
                }.disabled(selectedSong == nil)
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
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
    @MainActor
    private func applySong(_ searchResponse: MusicItem, for searchTerm: String) {
        if self.searchTerm == searchTerm {
            self.songMusicItem = searchResponse
        }
    }
    
    /// Safely updates the `albums` property on the main thread.
    @MainActor
    private func apply(_ searchResponse: [MusicItem], for searchTerm: String) {
        if self.searchTerm == searchTerm {
            self.songs = searchResponse
        }
    }
    
    /// Safely resets the `albums` property on the main thread.
    @MainActor
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

    var body: some View {
        HStack(alignment: .center) {
            VStack {
                Text("Active").font(.footnote)
                Button {
                    active.toggle()
                } label: {
                    Image(systemName: active ? "checkmark.square" : "square").font(.title)
                }
                .disabled(song.musicItemId.isEmpty || currentLoop.stop == 0 || currentLoop.start >= currentLoop.stop)
                Text("").font(.footnote)
            }
            
            TextField("Looptitle", text: $currentLoop.title)
                .autocorrectionDisabled(true)
                .disabled(song.musicItemId.isEmpty)
                .font(.body)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SetButtonView(song: song, txt: "Start", point: $currentLoop.start)
            SetButtonView(song: song, txt: "End", point: $currentLoop.stop)
            
            VStack {
                Text("Save").font(.footnote)
                Button {
                    saveToList()
                } label: {
                    Image(systemName: "square.and.arrow.down").font(.title)
                }
                .disabled(song.musicItemId.isEmpty || currentLoop.stop == 0 || currentLoop.start >= currentLoop.stop)
                Text("").font(.footnote)
            }
        }
    }
    
    func saveToList() {
        if currentLoop.title.trimmingCharacters(in: .whitespaces).isEmpty { return }
        
        // currentLoop in song.playerLoops suchen
        // wenn gefunden, dann updaten
        let list = song.playerLoops
        if let listIndex = list.firstIndex(where: { $0.title == currentLoop.title }) {
            list[listIndex].start = currentLoop.start
            list[listIndex].stop = currentLoop.stop
            list[listIndex].title = currentLoop.title
            song.playerLoops = list
        } else {
            // wenn nicht gefunden, dann currentLoop neu hinzufügen
            song.playerLoops.append(PlayerLoop(start: currentLoop.start, stop: currentLoop.stop, title: currentLoop.title.trimmingCharacters(in: .whitespaces).isEmpty ? "Loop \(song.playerLoops.count)" : currentLoop.title))
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
            Button { point = audioPlayer.songPosition } label: { Image(systemName: "button.programmable").font(.title) }.disabled(song.musicItemId.isEmpty)
            Text(formatTimeInterval(point)).font(.footnote)
        }
    }
                
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: timeInterval) ?? "00:00"
    }
}
