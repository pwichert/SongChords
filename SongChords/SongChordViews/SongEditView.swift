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
    @Environment(ViewModel.self) private var viewModel

    @State private var title: String = ""
    @State private var srcText: String = ""
    @State private var transpose: Double = 0
    
    var body: some View {
        Form {
            TextField("Title", text: $title)
            
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
            
            VStack {
                Text("ChordPro Text").foregroundStyle(Color(.lightGray))
                TextEditor(text: $srcText)
                    .monospaced()
                    #if os(iOS)
                    .frame(minHeight: 400)
                    #else
                    .frame(minWidth: 500, minHeight: 400)
                    #endif
                    .border(Color(.lightGray))
            }.padding(.top, 20)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled(true)
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
                        if changed { song.processSongInBackground(viewModel: viewModel) }
                    } else {
                        changed = true
                        let song = Song(title: title)
                        modelContext.insert(song)
                        song.srcText = srcText
                        song.transpose = Int(transpose)
                        song.toPlaylist(playlist: playlist)

                        song.processSongInBackground(viewModel: viewModel)
                    }
                    
                    dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
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
