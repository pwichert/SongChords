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
    @Bindable var song: Song
    @Binding var currentLoop: PlayerLoop
    @Binding var selectedLoop: PlayerLoop?
    @Binding var loopActive: Bool
    @Binding var songSpeed: Double
    @Binding var songPosition: TimeInterval
    @Binding var songPitch: Float
    @Binding var songMP3Uuid: String

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(Globals.self) private var globals
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var loopTimerManager

    @State private var showSongSearch: Bool = false
    @State private var showMP3Import: Bool = false
    @State private var inPositionEditing: Bool = false
    @State private var buttonBusy: Bool = false
    @State private var showSmallView: Bool = false
    @State private var songPitchText: String = ""

    // aktualisiert den Status des AudioPlayers, insb. die Position
    let statusTimer = Timer.publish(every: 1, tolerance: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            if !audioPlayer.isAllowed {
                AudioPlayerNotAllowedView().padding()
            } else {
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
                                .foregroundStyle(validLoop(loop: playerLoop) ? Color.primary : Color.red)
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
                    Grid(alignment: .trailing) {
                        GridRow {
                            Text("Pos")
                            Slider(value: $songPosition, in: 0...1.0, onEditingChanged: { editing in
                                if editing {
                                    inPositionEditing = true
                                } else {
                                    audioPlayer.songPosition = songPosition * audioPlayer.songDuration
                                    inPositionEditing = false
                                }
                            }).disabled(GlobalFunctions.isDisabled(song: song))
                            Text(GlobalFunctions.formatTimeInterval(songPosition * audioPlayer.songDuration)).font(.footnote).frame(width: 50).lineLimit(1)
                        }
                        GridRow {
                            Text("Speed")
                            Slider(value: $songSpeed, in: 0.3...1.0, onEditingChanged: { editing in
                                if !editing { audioPlayer.songSpeed = Float(songSpeed); setCurrentLoopTimer() }
                            }).disabled(GlobalFunctions.isDisabled(song: song))
                            Text("\(Int(round(songSpeed * 100.0)))%").font(.footnote).frame(width: 50).lineLimit(1)
                        }
                        
                        if audioPlayer.isMP3Player {
                            GridRow {
                                Text("Pitch")
                                Slider(value: $songPitch, in: -110...110, onEditingChanged: { editing in
                                    if !editing { audioPlayer.songPitch = songPitch * 10.0; setSongPitch(songPitch * 10.0) }
                                }).disabled(!audioPlayer.isMP3Player || GlobalFunctions.isDisabled(song: song))
                                TextField("", text: $songPitchText).autocorrectionDisabled(true)
                                    #if os(iOS)
                                    .keyboardType(.numbersAndPunctuation)
                                    #endif
                                    .font(.footnote).frame(width: 50).lineLimit(1)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.center)
                                    .onSubmit {
                                        if let newValue = Float(songPitchText),
                                           newValue >= -11, newValue <= 11 {
                                            songPitch = newValue * 10.0
                                            audioPlayer.songPitch = songPitch * 10.0
                                            setSongPitch(songPitch * 10.0)
                                        } else {
                                            songPitchText = String(format: "%.2f", songPitch / 10.0) // Falls ungültige Eingabe
                                        }
                                    }
                                    .disabled(GlobalFunctions.isDisabled(song: song))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .font(.footnote)
                }
                
                if shouldOfferSubscription {
                    subscriptionOfferButton
                } else {
                    ZStack {
                        if !showSmallView {
                            HStack {
                                Spacer()
                                Button(action: { showSongSearch.toggle() } ) {
                                    Label("Select Apple Music", systemImage: "music.note.list")
                                }.buttonStyle(BorderedButtonStyle()).font(.footnote)
                                
                                Button(action: { showMP3Import.toggle() } ) {
                                    Label("Select MPEG File", systemImage: "document")
                                }.buttonStyle(BorderedButtonStyle()).font(.footnote)
                                
                                Spacer()
                                Button(action: { showSmallView.toggle() }) {
                                    Image(systemName: showSmallView ? "chevron.up.circle" : "chevron.down.circle").font(.body).bold().labelStyle(.iconOnly)
                                }.buttonStyle(BorderedButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 500)
        // Display the subscription offer when appropriate.
        .musicSubscriptionOffer(isPresented: $isShowingSubscriptionOffer, options: subscriptionOfferOptions)
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
        .onChange(of: songPitch, initial: true) { old, newValue in
            songPitchText = String(format: "%.2f", newValue / 10.0)
        }
        .onChange(of: loopActive, initial: false) {
            if audioPlayer.playerState == .playing { setCurrentLoopTimer() }
        }
        .onChange(of: selectedLoop, initial: false) {
            if let selectedLoop {
                // currentLoop übernimmt die Werte der Auswahl in neuem Objekt, nicht das Objekt selbst
                currentLoop = PlayerLoop(start: selectedLoop.start, stop: selectedLoop.stop, title: selectedLoop.title)
                if audioPlayer.playerState == .playing { setCurrentLoopTimer() }
            }
        }
        .onChange(of: currentLoop.start, initial: false) {
            if audioPlayer.playerState == .playing { setCurrentLoopTimer() }
        }
        .onChange(of: currentLoop.stop, initial: false) {
            if audioPlayer.playerState == .playing { setCurrentLoopTimer() }
        }
        .onReceive(statusTimer) { time in
            // Songfortschritt anzeigen
            // print("statusTimer: time \(time) state \(audioPlayer.playerState) position \(audioPlayer.songPosition)")
            if !inPositionEditing {
                songPosition = audioPlayer.songDuration == 0 ? 0 : audioPlayer.songPosition / audioPlayer.songDuration
            }
        }
        .onChange(of: audioPlayer.playerState, initial: false) {
            buttonBusy = false
        }
        // Start observing changes to the music subscription.
        .task {
            print("subscription observer gestartet")
            for await subscription in MusicSubscription.subscriptionUpdates {
                musicSubscription = subscription
            }
            print("subscription observer gestoppt")
        }
    }

    var playbackButtonsView: some View {
        HStack {
            Spacer()
            Button(action: { rewindPlayback() }) {
                HStack(alignment: .center, spacing: 1) {
                    Label("rewind", systemImage: "play.fill").rotationEffect(.degrees(180)).labelStyle(.iconOnly)
                    Label("rewind", systemImage: "play.fill").rotationEffect(.degrees(180)).labelStyle(.iconOnly)
                }.padding(.horizontal)
            }.disabled(GlobalFunctions.isDisabled(song: song))
            
            Button(action: { Task { await startPlayback() }}) {
                HStack(alignment: .center, spacing: nil) {
                    if buttonBusy {
                        ProgressView().progressViewStyle(.circular).controlSize(.mini)
                    } else {
                        audioPlayer.playerState == .playing ? Image(systemName: "pause.fill") : Image(systemName: "play.fill")
                    }
                    Text(audioPlayer.playerState == .playing ? "Pause" : "Play")
                }.frame(minWidth: 70) // hält die Buttonbreite konstant, wenn sich Texte Pause/Play ändern
            }.disabled(GlobalFunctions.isDisabled(song: song) || shouldOfferSubscription)
            
            Button(action: { stopPlayback() }) {
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
    
    var smallLargeToggleView: some View {
        HStack {
            Spacer()
            Button(action: { showSmallView.toggle() }) { Label("", systemImage: showSmallView ? "chevron.up.circle" : "chevron.down.circle").font(.body).bold().labelStyle(.iconOnly) }
                .buttonStyle(BorderedButtonStyle())
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
    
    @State private var isLoopTimerRunning = false
    private func setCurrentLoopTimer(_ load: Bool = true) {
        guard !isLoopTimerRunning else { return }
        isLoopTimerRunning = true
        
        Task {
            defer { isLoopTimerRunning = false } // Flag zurücksetzen, wenn die Task endet

            if load { let _ = await audioPlayer.load(song: song) }
            
            if loopActive && validLoop(loop: currentLoop) {
                if audioPlayer.songPosition <= currentLoop.start || audioPlayer.songPosition >= currentLoop.stop {
                    audioPlayer.songPosition = currentLoop.start
                    startLoopTimer(interval: currentLoop.stop - currentLoop.start)
                } else {
                    let rest = currentLoop.stop - audioPlayer.songPosition
                    resumeLoopTimer(remainingInterval: rest, normalInterval: currentLoop.stop - currentLoop.start)
                }
            } else {
                stopLoopTimer()
            }
        }
    }
    
    private func startPlayback() async {
        let plState = audioPlayer.playerState
        
        buttonBusy = true
        
        if plState == .playing {
            audioPlayer.pause()
            stopLoopTimer()
        } else {
            // falls Fehler auftritt, Spinner weg
            if await audioPlayer.loadAndPlay(song: song) == false { buttonBusy = false }
            
            setCurrentLoopTimer(false)
        }
    }

    private func stopPlayback() {
        buttonBusy = false
        
        audioPlayer.stop()
        stopLoopTimer()
    }

    private func rewindPlayback() {
        if loopActive {
            audioPlayer.songPosition = currentLoop.start
        } else {
            audioPlayer.songPosition = 0
        }
        setCurrentLoopTimer()
    }
    
    private func validLoop(loop: PlayerLoop) -> Bool {
        guard audioPlayer.isLoaded else { return true }
        let songDuration = audioPlayer.songDuration
        return loop.start < songDuration && loop.stop < songDuration + 0.1 && loop.start < loop.stop
    }
    
    private func setSongPitch(_ pitch: Float) {
        do {
            song.setMP3Info(uuid: songMP3Uuid, pitch: pitch)
            try modelContext.save()
        } catch(let error) {
            globals.setSongChordsError(error: error)
        }
    }
    
    private func importMP3File(song: Song, urls: [URL]) {
        do {
            let fileManager = FileManager.default
            let destDir = try GlobalFunctions.mp3Path()
            
            for url in urls {
                print("Lade \(url.absoluteString)")
                
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
                songMP3Uuid = uuid
                songPitch = pitch / 10.0
                audioPlayer.isMP3Player = true
                
                break
            }
        } catch(let error) {
            print("Fehler beim mp3-Laden: \(error.localizedDescription)")
            globals.setSongChordsError(error: error)
        }
    }
    
    // MARK: - Subscription offer
    
    /// The Apple Music subscription of the current user.
    @State private var musicSubscription: MusicSubscription?
    
    /// `true` when the album detail view needs to offer an Apple Music subscription to the user.
    private var shouldOfferSubscription: Bool {
        let canBecomeSubscriber = musicSubscription?.canBecomeSubscriber ?? false
        return canBecomeSubscriber
    }
    
    private var subscriptionOfferButton: some View {
        Button(action: handleSubscriptionOfferButtonSelected) {
            HStack {
                Image(systemName: "applelogo")
                Text("Join")
            }
            .frame(maxWidth: 200)
        }
        .buttonStyle(BorderedProminentButtonStyle())
    }
    
    /// The state that controls whether the album detail view displays a subscription offer for Apple Music.
    @State private var isShowingSubscriptionOffer = false
    
    /// The options for the Apple Music subscription offer.
    @State private var subscriptionOfferOptions: MusicSubscriptionOffer.Options = .default
    
    /// Computes the presentation state for a subscription offer.
    private func handleSubscriptionOfferButtonSelected() {
        subscriptionOfferOptions.messageIdentifier = .join
        subscriptionOfferOptions.itemID = MusicItemID(song.musicItemId)
        isShowingSubscriptionOffer = true
    }
}

struct AudioPlayerNotAllowedView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    var body: some View {
        VStack {
            Text("Audio playback is not allowed in this app")
            Button("Open Settings") {
                #if os(macOS)
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                    NSWorkspace.shared.open(url)
                }
                #else
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }.buttonStyle(BorderedButtonStyle()).padding()
        }
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
                        song.tryRemoveMP3() // falls schon MP3 geladen wurde, erst löschen
                        song.musicItemId = id
                        audioPlayer.isMP3Player = false
                        try modelContext.save()
                        Task { await audioPlayer.load(song: song) }
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
                .disabled(GlobalFunctions.isDisabled(song: song) || currentLoop.stop == 0 || currentLoop.start >= currentLoop.stop)
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
                .disabled(GlobalFunctions.isDisabled(song: song) || currentLoop.stop == 0 || currentLoop.start >= currentLoop.stop)
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
            Button { point = audioPlayer.songPosition } label: { Image(systemName: "button.programmable").font(.title) }.disabled(GlobalFunctions.isDisabled(song: song))
            Text(GlobalFunctions.formatTimeInterval(point)).font(.footnote)
        }
    }
}
