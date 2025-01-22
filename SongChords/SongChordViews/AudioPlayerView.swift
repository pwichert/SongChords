//
//  AudioPlayerView.swift
//  SongChords
//
//  Created by Peter Wichert on 21.01.25.
//

import SwiftUI
import MusicKit

struct AudioPlayerView: View {
    let song: Song
    
    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var songSpeed: Double = 1.0
    @State private var songPosition: Double = 0.0
    @State private var showSongSearch: Bool = false
    
    let timer = Timer.publish(every: 1, tolerance: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            if !audioPlayer.isAllowed {
                Text("AudioPlayer/AppleMusic ist not available").padding()
            } else {
                HStack {
                    Button(action: startPlayback) {
                        audioPlayer.playerState == .playing ? Label("Pause", systemImage: "pause.fill") : Label("Play", systemImage: "play.fill")
                    }.disabled(song.musicItemId == "")
                    Button(action: stopPlayback) {
                        Label("Stop", systemImage: "stop.fill")
                    }.disabled(song.musicItemId == "")
                    Button(action: { showSongSearch.toggle() } ) {
                        Label("Select Song", systemImage: "music.note.list")
                    }
                }.buttonStyle(BorderedButtonStyle()).font(.footnote)
                
                Grid(alignment: .trailing) {
                    GridRow {
                        Text("Pos")
                        Slider(value: $songPosition, in: 0...1.0, step: 0.01, onEditingChanged:
                                { editing in
                            if !editing { audioPlayer.songPosition = songPosition }
                        }
                        ) {}
                        Text(formatTimeInterval(songPosition * audioPlayer.songDuration)).font(.footnote).frame(width: 50).lineLimit(1)
                    }
                    GridRow {
                        Text("Speed")
                        Slider(value: $songSpeed, in: 0.3...1.0, step: 0.01, onEditingChanged:
                                { editing in
                            if !editing { audioPlayer.songSpeed = Float(songSpeed) }
                        }
                        ) {}
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
        .onReceive(timer) { time in
            // Songfortschritt anzeigen
            // print("time \(time) state \(audioPlayer.playerState) position \(audioPlayer.songPosition)")
            songPosition = audioPlayer.songPosition
        }
        .onAppear {
            // bei jedem Anzeigen der View aktualisieren, laufenden Song nicht unterbrechen
            songSpeed = Double(audioPlayer.songSpeed)
            songPosition = audioPlayer.songPosition
        }
        .task(id: song.persistentModelID) {
            // beim ersten Anzeigen des Songs
            audioPlayer.load(id: song.musicItemId)
        }
    }
    
    private func startPlayback() {
        // Implement playback functionality using Apple Music or local audio playback.
        
        if audioPlayer.playerState == .playing {
            audioPlayer.pause()
        } else if audioPlayer.playerState == .paused {
            audioPlayer.play()
        } else {
            if !audioPlayer.isLoaded {
                audioPlayer.load(id: song.musicItemId)
            }
            
            audioPlayer.play()
        }
    }

    private func stopPlayback() {
        audioPlayer.stop()
    }

    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: timeInterval) ?? "00:00"
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
            Text("Set Apple Music Title for this Song").font(.headline).padding()
            TextField("Search", text: $searchTerm)
                .textFieldStyle(.roundedBorder)
                .padding()
    
            searchResultsList
                .animation(.default, value: songs)
        }.frame(maxWidth: 500, idealHeight: 500)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    do {
                        let id = String(selectedSong?.id ?? "")
                        song.musicItemId = id
                        try modelContext.save()
                        audioPlayer.load(id: id)
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
                    Text("Abort")
                }
            }
        }
        .navigationTitle("Apple Music Search")
        .onChange(of: searchTerm) { requestUpdatedSearchResults(for: searchTerm) }
        .onAppear {
            searchTerm = song.title
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
                .navigationTitle("Music Songs")
        }
        .searchable(text: $searchTerm, prompt: "Songs")
    }
    
    // MARK: - Search results requesting
    
    /// The current search term the user enters.
    @State private var searchTerm = ""
    
    /// The albums the app loads using MusicKit that match the current search term.
    @State private var songs: [MusicItem] = []
    @State private var selectedSong: MusicItem?
    
    /// A list of albums to display below the search bar.
    private var searchResultsList: some View {
        List(songs, id: \.self, selection: $selectedSong) { musicSong in
            Text("\(musicSong.title) - \(musicSong.artistName)")
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
                            artistName: song.artistName
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

struct AppleMusicSearchView: View {
    @State private var searchText: String = ""
    @State private var searchResults: [MusicItem] = []
    @State private var isSearching: Bool = false
    let song: Song // Das Song-Objekt, in dem die MusicItemID gespeichert werden soll

    var body: some View {
        VStack {
//            TextField("Search Apple Music", text: $searchText, onCommit: search)
            TextField("Search Apple Music", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .disableAutocorrection(true)

            if isSearching {
                ProgressView("Searching...")
                    .padding()
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Text("No results found.")
                    .padding()
            } else {
                List(searchResults, id: \.id) { item in
                    Button(action: {
                        saveMusicItemID(item.id)
                    }) {
                        HStack {
                            Text(item.title)
                                .font(.headline)
                            Spacer()
                            Text(item.artistName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Apple Music Search")
        .onAppear {
            requestMusicAuthorization()
        }
    }

//    private func search() {
//        guard !searchText.isEmpty else { return }
//        isSearching = true
//
//        Task {
//            do {
//                let request = MusicCatalogSearchRequest(term: searchText, types: [MusicKit.Song.self])
//                let response = try await request.response()
//                self.searchResults = response.songs.map { MusicItem(id: $0.id.rawValue, title: $0.title, artistName: $0.artistName) }
//            } catch {
//                print("Error searching Apple Music: \(error.localizedDescription)")
//            }
//            isSearching = false
//        }
//    }

    private func saveMusicItemID(_ id: String) {
        song.musicItemId = id // Speichere die ID im Song-Modell
        print("Saved MusicItemID: \(id)")
    }

    private func requestMusicAuthorization() {
        Task {
            let status = await MusicAuthorization.request()
            if status != .authorized {
                print("Apple Music authorization not granted.")
            }
        }
    }
}

struct MusicItem: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let artistName: String
}
