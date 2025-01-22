struct AudioPlayerView: View {
    let song: Song
    
    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var songSpeed: Double = 1.0
    @State private var songPosition: Double = 0.0
    @State private var showSongSearch: Bool = false
    
    let timer = Timer.publish(every: 1, tolerance: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            HStack {
                Button(action: startPlayback) {
                    audioPlayer.playerState == .playing ? Label("Pause", systemImage: "pause.fill") : Label("Play", systemImage: "play.fill")
                }
                Button(action: stopPlayback) {
                    Label("Stop", systemImage: "stop.fill")
                }
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
        .sheet(isPresented: $showSongSearch) {
            NavigationStack {
                MusicContentView(song: song)
            }
        }
        .onReceive(timer) { time in
//            print("time \(time) state \(audioPlayer.playerState) position \(audioPlayer.songPosition)")
            songPosition = audioPlayer.songPosition
//            if audioPlayer.songSpeed != 0 { songSpeed = Double(audioPlayer.songSpeed) }
        }
        .onChange(of: song, initial: true) {
            audioPlayer.loadSong(song: song)
            songPosition = audioPlayer.songPosition
        }
    }
    
    private func startPlayback() {
        // Implement playback functionality using Apple Music or local audio playback.
        
        if audioPlayer.playerState == .playing {
            audioPlayer.pause()
        } else if audioPlayer.playerState == .paused {
            audioPlayer.play()
        } else {
            if !audioPlayer.songLoaded() {
                audioPlayer.loadSong(song: song)
            }
            
            audioPlayer.play()
        }
    }

    private func stopPlayback() {
        audioPlayer.stop()
    }

    func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: timeInterval) ?? "00:00"
    }
}

struct MusicContentView: View {
    var song: Song
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - View
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Set Apple Music Title for this Song").font(.headline).padding()
            TextField("Search", text: $searchTerm)
                .textFieldStyle(.roundedBorder)
                .padding()
                .frame(maxWidth: 500)
    
            searchResultsList
                .animation(.default, value: songs)
        }.frame(idealHeight: 500)
        .onChange(of: searchTerm) { requestUpdatedSearchResults(for: searchTerm) }
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
    @State private var songs: MusicItemCollection<MusicKit.Song> = []
        
    /// A list of albums to display below the search bar.
    private var searchResultsList: some View {
        List(songs) { musicSong in
            Button {
                song.musicItemId = String(describing: musicSong.id);
                try? modelContext.save()
                dismiss()
            } label: {
                Text("\(musicSong.title) - \(musicSong.artistName)")
            }
        }
    }
    
    /// Makes a new search request to MusicKit when the current search term changes.
    private func requestUpdatedSearchResults(for searchTerm: String) {
        Task {
            if searchTerm.isEmpty {
                self.reset()
            } else {
                do {
                    // Issue a catalog search request for albums matching the search term.
                    var searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [MusicKit.Song.self])
                    searchRequest.limit = 5
                    let searchResponse = try await searchRequest.response()
                    
                    // Update the user interface with the search response.
                    self.apply(searchResponse, for: searchTerm)
                } catch {
                    print("Search request failed with error: \(error).")
                    self.reset()
                }
            }
        }
    }
    
    /// Safely updates the `albums` property on the main thread.
    @MainActor
    private func apply(_ searchResponse: MusicCatalogSearchResponse, for searchTerm: String) {
        if self.searchTerm == searchTerm {
            self.songs = searchResponse.songs
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
            TextField("Search Apple Music", text: $searchText, onCommit: search)
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

    private func search() {
        guard !searchText.isEmpty else { return }
        isSearching = true

        Task {
            do {
                let request = MusicCatalogSearchRequest(term: searchText, types: [MusicKit.Song.self])
                let response = try await request.response()
                self.searchResults = response.songs.map { MusicItem(id: $0.id.rawValue, title: $0.title, artistName: $0.artistName) }
            } catch {
                print("Error searching Apple Music: \(error.localizedDescription)")
            }
            isSearching = false
        }
    }

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

struct MusicItem: Identifiable {
    let id: String
    let title: String
    let artistName: String
}
