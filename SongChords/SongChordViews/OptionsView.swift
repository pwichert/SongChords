//
//  OptionsView.swift
//  SongChords
//
//  Created by Peter Wichert on 12.11.24.
//

import SwiftUI

struct OptionsView: View {
    @Environment(ViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var chordSize: Double = 0
    @State private var txtSize: Double = 0
    @State private var headerSize: Double = 0
    @State private var isGermanNotation: Bool = false
    @State private var textFollowsChords: Bool = false
    @State private var hideChords: Bool = false
    @State private var displayMode: DisplayMode = .automatic
    
    var body: some View {
        Form {
            Picker("Display Mode", selection: $displayMode) {
                Text("light").tag(DisplayMode.light)
                Text("dark").tag(DisplayMode.dark)
                Text("system").tag(DisplayMode.automatic)
            }.pickerStyle(.segmented)
            #if os(macOS)
                .padding(.bottom, 4)
            #endif

            Section {
                Toggle("Hide Chords", isOn: $hideChords)
            }
            #if os(macOS)
                .padding(.bottom, 4)
            #endif

            #if os(macOS)
            Section(footer: Text("The text is always positioned below the chord").font(.footnote).padding(.bottom, 4)) {
                Toggle("Text follows Chords", isOn: $textFollowsChords).disabled(hideChords)
            }
            #else
            Section(footer: Text("The text is always positioned below the chord")) {
                Toggle("Text follows Chords", isOn: $textFollowsChords).disabled(hideChords)
            }
            #endif

            Section {
                Toggle("German Notation", isOn: $isGermanNotation)
            }
            #if os(macOS)
                .padding(.bottom, 4)
            #endif
            
            HStack {
                #if os(iOS)
                Text("Headersize [\(Int(headerSize))]")
                Spacer()
                #endif
                Slider(
                    value: $headerSize,
                    in: 5...20,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Headersize [\(Int(headerSize))]")
                }
            }
            #if os(macOS)
                .padding(.bottom, 4)
            #endif

            HStack {
                #if os(iOS)
                Text("Chordsize [\(Int(chordSize))]")
                Spacer()
                #endif
                Slider(
                    value: $chordSize,
                    in: 5...20,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Chordsize [\(Int(chordSize))]")
                }
            }
            #if os(macOS)
                .padding(.bottom, 4)
            #endif

            HStack {
                #if os(iOS)
                Text("Textsize [\(Int(txtSize))]")
                Spacer()
                #endif
                Slider(
                    value: $txtSize,
                    in: 5...20,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Textsize [\(Int(txtSize))]")
                }
            }
        }
        .onChange(of: hideChords, initial: false) {
            if hideChords { textFollowsChords = false }
        }
        #if os(macOS)
        .padding()
        #endif
        .navigationTitle("Options")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if Int(chordSize) != Int(viewModel.chordsize) { viewModel.chordsize = chordSize }
                    if Int(txtSize) != Int(viewModel.txtsize) { viewModel.txtsize = txtSize }
                    if Int(headerSize) != Int(viewModel.headersize) { viewModel.headersize = headerSize }
                    if isGermanNotation != viewModel.isGermanNotation { viewModel.isGermanNotation = isGermanNotation }
                    if hideChords != viewModel.hidechords { viewModel.hidechords = hideChords }
                    if textFollowsChords != viewModel.textfollowschords { viewModel.textfollowschords = textFollowsChords }
                    if displayMode != viewModel.displayMode { viewModel.displayMode = displayMode }
                    
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
            chordSize = viewModel.chordsize
            txtSize = viewModel.txtsize
            headerSize = viewModel.headersize
            isGermanNotation = viewModel.isGermanNotation
            hideChords = viewModel.hidechords
            textFollowsChords = viewModel.textfollowschords
            displayMode = viewModel.displayMode
        }
    }
}

struct PrintOptionsView: View {
    @Environment(ViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var chordSize: Double = 0
    @State private var txtSize: Double = 0
    @State private var headerSize: Double = 0
    
    var body: some View {
        Form {
            HStack {
                #if os(iOS)
                Text("Headersize [\(Int(headerSize))]")
                Spacer()
                #endif
                Slider(
                    value: $headerSize,
                    in: 5...20,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Headersize [\(Int(headerSize))]")
                }
            }
            #if os(macOS)
                .padding(.bottom, 4)
            #endif

            HStack {
                #if os(iOS)
                Text("Chordsize [\(Int(chordSize))]")
                Spacer()
                #endif
                Slider(
                    value: $chordSize,
                    in: 5...20,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Chordsize [\(Int(chordSize))]")
                }
            }
            #if os(macOS)
                .padding(.bottom, 4)
            #endif

            HStack {
                #if os(iOS)
                Text("Textsize [\(Int(txtSize))]")
                Spacer()
                #endif
                Slider(
                    value: $txtSize,
                    in: 5...20,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Textsize [\(Int(txtSize))]")
                }
            }
        }
        #if os(macOS)
        .padding()
        #endif
        .navigationTitle("PDF Options")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if Int(chordSize) != Int(viewModel.chordsizepdf) { viewModel.chordsizepdf = chordSize }
                    if Int(txtSize) != Int(viewModel.txtsizepdf) { viewModel.txtsizepdf = txtSize }
                    if Int(headerSize) != Int(viewModel.headersizepdf) { viewModel.headersizepdf = headerSize }
                    
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
            chordSize = viewModel.chordsizepdf
            txtSize = viewModel.txtsizepdf
            headerSize = viewModel.headersizepdf
        }
    }
}

struct InfoTextView: View {
    @Environment(ViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                Spacer()
                Text(viewModel.getVersion()).font(.title)
                Spacer()
            }.padding(.bottom, 20)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("How to create a song?").font(.headline)
                Text(" ")
                Section {
                    Text("For all variants, you first create/select a playlist, as the new song will be associated with that playlist.")
                }
                Section(header: Text("1st Option")) {
                    Text("If you have already displayed the song somewhere in the typical chord/text format, e.g., in a browser or PDF:")
                    
                    VStack(alignment: .leading) {
                        Text("Am          C")
                        Text("The sky was blue")
                        Text("...")
                    }.fontDesign(.monospaced).lineSpacing(0)
                    
                    Text("Then you can copy it to the clipboard by selecting/copying. In the app, you can import the song into a playlist by using 'Import Text Clipboard'. It will attempt to recognize as much as possible and display it in a meaningful format.")
                }
                Section(header: Text("2nd Option")) {
                    Text("You can import a ChordPro file; the app understands the key directives. The song can be inserted into a playlist using 'Import ChordPro File'. The ChordPro file should have the extension .chpro")
                }
                Section(header: Text("3rd Option")) {
                    Text("You create a new template by selecting 'New Song Template'. You can customize this template to your preferences using 'Edit ChordPro Text'.")
                }
                Text(" ")
                Section {
                    Text("You initially see the live representation of the song. By toggling with 'Toggle PDF', the display switches to print view, taking ChordPro directives into account.")
                }
            }
        }
    }
}

struct InfoView: View {    
    var body: some View {
        InfoContentView("Info") {
            InfoTextView()
        }
    }
}
