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
    
    @State private var showSrcEditor: Bool = false
    
    var body: some View {
        Form {
            TextField("Title", text: $title)
            #if os(macOS)
                .padding(.bottom, 4)
            #endif
            
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
            #if os(macOS)
                .padding(.bottom, 4)
            #endif

            Button(action: { showSrcEditor.toggle() }) {
                Label("Edit ChordPro Text", systemImage: "doc")
            }
            #if os(macOS)
            .padding(.bottom, 4)
            #endif
        }
        #if os(macOS)
        .padding()
        #endif
        .navigationTitle((song == nil ? "" :  song?.title) ?? "")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var changed: Bool = false
                    
                    if let song {
                        if song.title != title { song.title = title }
                        if song.srcText != srcText {
                            song.srcText = srcText
                            changed = true
                        }
                        if song.transpose != Int(transpose) {
                            song.transpose = Int(transpose)
                            changed = true
                        }
                        if changed { song.processSongInBackground(userSettings: userSettings, forPrinting: false) }
                    } else {
                        do {
                            let song = try Song(title: title, modelContext: modelContext)
                            modelContext.insert(song)
                            try modelContext.save()
                            song.srcText = srcText
                            song.transpose = Int(transpose)
                            song.toPlaylist(playlist: playlist)
                            
                            song.processSongInBackground(userSettings: userSettings, forPrinting: false)
                            changed = true
                        } catch (let error) {
                            globals.setSongChordsError(error: error)
                        }
                    }
                    
                    dismiss()
                }.disabled(title.isEmpty || !Song.isValidFilename(title))
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
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
                srcText = song.srcText
                transpose = Double(song.transpose)
            }
        }
    }
}

struct ChordProEditorView: View {
    @Binding var srcText: String
    
    @Environment(\.dismiss) private var dismiss

    @State private var t: String = ""
    
    var body: some View {
        TextEditor(text: $t)
            .monospaced()
            .autocorrectionDisabled(true)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #else
            .frame(idealHeight: 500)
            #endif
            .onAppear() {
                t = srcText
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if srcText != t { srcText = t }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
    }
}
