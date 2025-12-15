//
//  ContentView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var visibility: NavigationSplitViewVisibility = .all
    @State private var selectedPlaylistID: PersistentIdentifier?
    @State private var selectedSongIDs: Set<PersistentIdentifier> = []
    @State private var showAlert: Bool = false

    @Environment(TimerManager.self) private var timerManager
    @Environment(UserSettings.self) private var userSettings
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(Globals.self) private var globals
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {

            PlayListView(selectedPlaylistID: $selectedPlaylistID, visibility: $visibility)
                .environment(userSettings)
                .environment(globals)
                .environment(audioPlayer)
                .environment(timerManager)
            
        } content: {
            
            if let selectedPlaylistID = selectedPlaylistID, let selectedPlaylist = PlayList.fetchPlaylist(with: selectedPlaylistID, in: modelContext) {
                SongListView(playlist: selectedPlaylist, visibility: $visibility, selectedSongIDs: $selectedSongIDs)
                    .environment(userSettings)
                    .environment(globals)
                    .environment(audioPlayer)
                    .environment(timerManager)
            } else {
                ContentUnavailableView("Select a playlist", systemImage: "doc.text.image.fill")
            }
            
        } detail: {
            
            if selectedSongIDs.count == 1, let selectedSongID = selectedSongIDs.first, let song = Song.fetchSongProcessing(with: selectedSongID, in: modelContext, userSettings: userSettings.makeSendable(), forPrinting: false) {
                SongView(song: song, visibility: $visibility)
                    .environment(userSettings)
                    .environment(globals)
                    .environment(audioPlayer)
                    .environment(timerManager)
            } else {
                ContentUnavailableView("Select a song", systemImage: "doc.text.image.fill")
            }
            
        }
        .alert((globals.songChordsError?.error as? SongChordsError)?.desc ?? globals.songChordsError?.error.localizedDescription ?? "??", isPresented: $showAlert) {
            Button("Ok") { }
        }
        .onChange(of: globals.songChordsError) { showAlert.toggle() }
        .onChange(of: selectedPlaylistID) { selectedSongIDs = [] }      // ContentUnavailable in SongView
        .navigationSplitViewStyle(.automatic)
        .preferredColorScheme(userSettings.displayMode == .dark ? .dark : (userSettings.displayMode == .light ? .light : nil))
    }
}


//import SwiftUI
//
//struct ContentView: View {
//    let store: SongChordsStore
//
//    @State private var selectedCategory: String?
//    @State private var selectedItem: String?
//    
//    let categories = ["Fruits", "Vegetables"]
//    let items = [
//        "Fruits": ["Apple", "Banana", "Cherry"],
//        "Vegetables": ["Carrot", "Broccoli", "Peas"]
//    ]
//    
//    var body: some View {
//        NavigationSplitView {
//            // Erste Liste: Kategorien
//            List(categories, id: \.self, selection: $selectedCategory) { category in
//                Text(category)
//            }
//            .navigationTitle("Categories")
//        } content: {
//            // Zweite Liste: Items basierend auf der ausgewählten Kategorie
//            if let selectedCategory = selectedCategory {
//                List(items[selectedCategory] ?? [], id: \.self, selection: $selectedItem) { item in
//                    Text(item)
//                }
//                .navigationTitle(selectedCategory)
//            } else {
//                Text("Select a Category")
//            }
//        } detail: {
//            // DetailView: Details für das ausgewählte Item
//            if let selectedItem = selectedItem {
//                DetailView(item: selectedItem)
//            } else {
//                Text("Select an Item")
//            }
//        }
//    }
//}
//
//struct DetailView: View {
//    let item: String
//    
//    var body: some View {
//        VStack {
//            Text("Details for \(item)")
//                .font(.title)
//            Spacer()
//        }
//        .padding()
//        .navigationTitle(item)
//        .onAppear {
//            print("appear \(item)")
//        }
//    }
//}
