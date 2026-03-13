//
//  SongEditView.swift
//  SongChords
//
//  Created by Peter Wichert on 10.11.24.
//

import SwiftUI

struct SongEditView: View {
    let playlist: PlayList
    let song: Song?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettings.self) private var userSettings
    @Environment(Globals.self) private var globals

    @State private var title: String = ""
    @State private var srcText: String = ""
    @State private var transpose: Double = 0
    @State private var showText: Bool = true
    
    @State private var showSrcEditor: Bool = false
    
    enum FocusedField: Hashable {
        case songTitle
    }
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        OptionsContentView {
            TextField("Title", text: $title)
                .focused($focusedField, equals: .songTitle)
                .autocorrectionDisabled()
//            #if os(macOS)
//                .padding(.bottom, 4)
//            #endif
            
            Section(footer: Text("Without lyrics, you could get a more compact overview of the chords.")
//                #if os(macOS)
//                .font(.footnote).padding(.bottom, 4)
//                #endif
            ){
                Toggle("Show Text", isOn: $showText)
            }
//            #if os(macOS)
//                .padding(.bottom, 4)
//            #endif
                        
            HStack {
                #if os(iOS)
                Text("Transpose [\(Int(transpose))]")
                Spacer()
                #endif
                Slider(
                    value: $transpose,
                    in: -11...11,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Transpose [\(Int(transpose))]")
                }
            }
//            #if os(macOS)
//                .padding(.bottom, 4)
//            #endif

            Button(role: .confirm, action: { showSrcEditor.toggle() }) {
                Label("Edit ChordPro Text", systemImage: "doc")
            }.help("Edit ChordPro Text")
//            #if os(macOS)
//            .padding(.bottom, 4)
//            #endif
        }
        .navigationTitle((song == nil ? "" :  song?.title) ?? "")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark") {
                    do {
                        var processSong: Bool = false

                        if let song {
                            if song.title != title { song.title = title }
                            if song.showText != showText { song.showText = showText }

                            if song.srcText != srcText {
                                song.srcText = srcText
                                processSong = true
                            }
                            if song.transpose != Int(transpose) {
                                song.transpose = Int(transpose)
                                processSong = true
                            }
                            
                            if processSong {
                                Task {
                                    await SongTaskManager.shared.processSongInBackground(srcText: song.srcText, transpose: song.transpose, showHeader: song.showHeader, showText: song.showText, userSettings: userSettings)
                                }
                            }
                            if modelContext.hasChanges { try modelContext.save() }
                        } else {
                            let song = try Song(title: title, srcText: srcText, transpose: Int(transpose), showChords: true, showText: showText, showHeader: true, duration: 0, musicItemId: "", playerLoops: [], backgroundColor: 0)
                            modelContext.insert(song)
                            song.toPlaylist(playlist: playlist)
                            
                            Task {
                                await SongTaskManager.shared.processSongInBackground(srcText: song.srcText, transpose: song.transpose, showHeader: song.showHeader, showText: song.showText, userSettings: userSettings)
                            }
                            try modelContext.save()
                        }
                    } catch (let error) {
                        globals.setSongChordsError(error: error)
                    }
                    
                    dismiss()
                }.disabled(title.isEmpty || !Song.isValidTitle(title))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showSrcEditor) {
            NavigationStack {
                ChordProEditorView(srcText: $srcText)
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            if let song {
                title = song.title
                showText = song.showText
                srcText = song.srcText
                transpose = Double(song.transpose)
            }
            
            #if os(iOS)
            focusedField = .songTitle
            #endif
        }
    }
}

struct ChordProEditorView: View {
    @Binding var srcText: String
    
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: FocusedField?
    @State private var t: String = ""
    
    enum FocusedField: Hashable {
        case songEditor
    }
    var body: some View {
        TextEditor(text: $t)
            .focused($focusedField, equals: .songEditor)
            .monospaced()
            .autocorrectionDisabled(true)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #else
            .frame(height: 500)
            #endif
            .onAppear() {
                t = srcText
                
            #if os(iOS)
                if t.isEmpty {
                    focusedField = .songEditor
                }
            #endif
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        t = t.replacingOccurrences(of: "\r", with: "")
                        if srcText != t { srcText = t }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
    }
}
