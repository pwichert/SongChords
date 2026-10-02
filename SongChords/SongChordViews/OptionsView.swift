//
//  OptionsView.swift
//  SongChords
//
//  Created by Peter Wichert on 12.11.24.
//

import SwiftUI

struct OptionsContentView<Content: View>: View {
    @ViewBuilder let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Form {
            content
        }
        #if os(macOS)
        .formStyle(.grouped)
        .frame(width: 400, height: 300)     // sonst -LayoutIfNeeded-Fehler
        #endif
    }
}

struct OptionsView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(\.dismiss) private var dismiss

    @State private var isIdleTimerDisabled: Bool = false
    @State private var chordSize: Double = 0
    @State private var txtSize: Double = 0
    @State private var headerSize: Double = 0
    @State private var isGermanNotation: Bool = false
    @State private var transposeKey: Bool = false
    @State private var textFollowsChords: Bool = false
    @State private var hideChords: Bool = false
    @State private var displayMode: DisplayMode = .automatic
    @State private var lineSpacing: Double = 0
        
    var body: some View {
        OptionsContentView {
            Picker("Display Mode", selection: $displayMode) {
                Text("light").tag(DisplayMode.light)
                Text("dark").tag(DisplayMode.dark)
                Text("system").tag(DisplayMode.automatic)
            }.pickerStyle(.segmented)
            
            #if os(iOS)
            Section(footer: Text("Do not lock device while SongChords is running.")
            ){
                Toggle("Lock device off", isOn: $isIdleTimerDisabled)
            }
            #endif

            Section(footer: Text("If you are a singer and don't need chords. This is global for all songs.")
            ){
                Toggle("Hide Chords", isOn: $hideChords)
            }

            Section(footer: Text("The text is always positioned below the chord.")
            ){
                Toggle("Text follows Chords", isOn: $textFollowsChords).disabled(hideChords)
            }

            Section {
                Toggle("German Notation", isOn: $isGermanNotation)
            }
            
            Section(footer: Text("Transpose according to the key signature or simply along the chromatic scale.")
            ){
                Toggle("Transpose Key", isOn: $transposeKey)
            }

            HStack {
                #if os(iOS)
                Text("Headersize [\(Int(headerSize))]")
                Spacer()
                #endif
                Slider(
                    value: $headerSize,
                    in: 5...30,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Headersize [\(Int(headerSize))]")
                }
            }

            HStack {
                #if os(iOS)
                Text("Chordsize [\(Int(chordSize))]")
                Spacer()
                #endif
                Slider(
                    value: $chordSize,
                    in: 5...30,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Chordsize [\(Int(chordSize))]")
                }
            }

            HStack {
                #if os(iOS)
                Text("Textsize [\(Int(txtSize))]")
                Spacer()
                #endif
                Slider(
                    value: $txtSize,
                    in: 5...30,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Textsize [\(Int(txtSize))]")
                }
            }

            HStack {
                #if os(iOS)
                Text("Linespacing [\(Int(lineSpacing))]")
                Spacer()
                #endif
                Slider(
                    value: $lineSpacing,
                    in: 4...20,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Linespacing [\(Int(lineSpacing))]")
                }
            }
        }
        .onChange(of: hideChords) { _, newValue in
            if newValue {
                textFollowsChords = false
            }
        }
        .navigationTitle("Options")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark") {
                    if isIdleTimerDisabled != userSettings.isIdleTimerDisabled { userSettings.isIdleTimerDisabled = isIdleTimerDisabled }
                    if Int(chordSize) != Int(userSettings.chordsize) { userSettings.chordsize = chordSize }
                    if Int(txtSize) != Int(userSettings.txtsize) { userSettings.txtsize = txtSize }
                    if Int(headerSize) != Int(userSettings.headersize) { userSettings.headersize = headerSize }
                    if isGermanNotation != userSettings.isGermanNotation { userSettings.isGermanNotation = isGermanNotation }
                    if transposeKey != userSettings.transposeKey { userSettings.transposeKey = transposeKey }
                    if hideChords != userSettings.hidechords { userSettings.hidechords = hideChords }
                    if textFollowsChords != userSettings.textfollowschords { userSettings.textfollowschords = textFollowsChords }
                    if Int(lineSpacing) != Int(userSettings.linespacing) { userSettings.linespacing = lineSpacing }
                    if displayMode != userSettings.displayMode { userSettings.displayMode = displayMode }

                    dismiss()
                }.labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark") {
                    dismiss()
                }.labelStyle(.iconOnly)
            }
        }
        .onAppear {
            isIdleTimerDisabled = userSettings.isIdleTimerDisabled
            chordSize = userSettings.chordsize
            txtSize = userSettings.txtsize
            headerSize = userSettings.headersize
            isGermanNotation = userSettings.isGermanNotation
            transposeKey = userSettings.transposeKey
            hideChords = userSettings.hidechords
            textFollowsChords = userSettings.textfollowschords
            displayMode = userSettings.displayMode
            lineSpacing = userSettings.linespacing
        }
    }
}

struct PrintOptionsView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(\.dismiss) private var dismiss

    @State private var chordSize: Double = 0
    @State private var txtSize: Double = 0
    @State private var headerSize: Double = 0
    @State private var lineSpacing: Double = 0
    
    var body: some View {
        OptionsContentView {
            HStack {
                #if os(iOS)
                Text("Headersize [\(Int(headerSize))]")
                Spacer()
                #endif
                Slider(
                    value: $headerSize,
                    in: 5...30,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Headersize [\(Int(headerSize))]")
                }
            }

            HStack {
                #if os(iOS)
                Text("Chordsize [\(Int(chordSize))]")
                Spacer()
                #endif
                Slider(
                    value: $chordSize,
                    in: 5...30,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Chordsize [\(Int(chordSize))]")
                }
            }

            HStack {
                #if os(iOS)
                Text("Textsize [\(Int(txtSize))]")
                Spacer()
                #endif
                Slider(
                    value: $txtSize,
                    in: 5...30,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Textsize [\(Int(txtSize))]")
                }
            }

            HStack {
                #if os(iOS)
                Text("Linespacing [\(Int(lineSpacing))]")
                Spacer()
                #endif
                Slider(
                    value: $lineSpacing,
                    in: 4...20,
                    step: 1,
                    minimumValueLabel:
                        Text("-"),
                    maximumValueLabel:
                        Text("+")
                ) {
                    Text("Linespacing [\(Int(lineSpacing))]")
                }
            }
        }
        .navigationTitle("PDF Options")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark") {
                    if Int(chordSize) != Int(userSettings.chordsizepdf) { userSettings.chordsizepdf = chordSize }
                    if Int(txtSize) != Int(userSettings.txtsizepdf) { userSettings.txtsizepdf = txtSize }
                    if Int(headerSize) != Int(userSettings.headersizepdf) { userSettings.headersizepdf = headerSize }
                    if Int(lineSpacing) != Int(userSettings.linespacingpdf) { userSettings.linespacingpdf = lineSpacing }
                    
                    dismiss()
                }.labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark") {
                    dismiss()
                }.labelStyle(.iconOnly)
            }
        }
        .onAppear {
            chordSize = userSettings.chordsizepdf
            txtSize = userSettings.txtsizepdf
            headerSize = userSettings.headersizepdf
            lineSpacing = userSettings.linespacingpdf
        }
    }
}
