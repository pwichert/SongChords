//
//  ContentView.swift
//  SongChords
//
//  Created by Peter Wichert on 07.11.24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    let store: SongChordsStore
    
    @State private var visibility: NavigationSplitViewVisibility = .all
    @State private var selectedPlaylistID: PersistentIdentifier?
    @State private var selectedSongIDs: Set<PersistentIdentifier> = []
    @State private var showAlert: Bool = false
    @State private var showStore: Bool = false

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
                .environment(store)
                .environment(audioPlayer)
                .environment(timerManager)
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 300, ideal: 300, max: 400)
                #endif
            
        } content: {
            
            if let selectedPlaylistID = selectedPlaylistID, let selectedPlaylist = PlayList.fetchPlaylist(with: selectedPlaylistID, in: modelContext) {
                SongListView(playlist: selectedPlaylist, visibility: $visibility, selectedSongIDs: $selectedSongIDs)
                    .environment(userSettings)
                    .environment(globals)
                    .environment(store)
                    .environment(audioPlayer)
                    .environment(timerManager)
                    #if os(macOS)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 300)
                    #endif
            } else {
                ContentUnavailableView("Select a playlist", systemImage: "doc.text.image.fill")
                    #if os(macOS)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 300)
                    #endif
            }
            
        } detail: {
            
            if selectedSongIDs.count == 1, let selectedSongID = selectedSongIDs.first, let song = Song.fetchSongProcessing(with: selectedSongID, in: modelContext, userSettings: userSettings.makeSendable(), forPrinting: false) {
                SongView(song: song, visibility: $visibility)
                    .environment(userSettings)
                    .environment(globals)
                    .environment(store)
                    .environment(audioPlayer)
                    .environment(timerManager)
            } else {
                ContentUnavailableView("Select a song", systemImage: "doc.text.image.fill")
            }
            
        }
        .alert((globals.songChordsError?.error as? SongChordsError)?.desc ?? globals.songChordsError?.error.localizedDescription ?? "??", isPresented: $showAlert) {
            Button("Ok") { }
        }
        .sheet(isPresented: $showStore) {
            NavigationStack {
                SongChordsStoreView(store: store, songChordsError: globals.songChordsError)
            }
        }
        .onChange(of: globals.songChordsError) { errorChanged() }
        .onChange(of: selectedPlaylistID) { selectedSongIDs = [] }      // ContentUnavailable in SongView
        .navigationSplitViewStyle(.automatic)
        .preferredColorScheme(userSettings.displayMode == .dark ? .dark : (userSettings.displayMode == .light ? .light : nil))
    }
    
    private func errorChanged() {
        // Falls es jemals weitere Purchases gibt, müsste die Liste für showStore.toggle() erweitert werden
        // Jeder Purchase wird von einem SongChordsError getriggert
        
        switch globals.songChordsError?.error as? SongChordsError {
        case .limitReached:
            showStore.toggle()
        default:
            showAlert.toggle()
        }
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
