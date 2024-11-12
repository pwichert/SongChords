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
    @State private var displayMode: DisplayMode = .automatic
    
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
         
            Picker("Display Mode", selection: $displayMode) {
                Text("light").tag(DisplayMode.light)
                Text("dark").tag(DisplayMode.dark)
                Text("system").tag(DisplayMode.automatic)
            }.pickerStyle(.segmented)
            
            Toggle("German Notation", isOn: $isGermanNotation)
        }
        #if os(macOS)
        .padding()
        #endif
        .navigationTitle(viewModel.getVersion())
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if Int(chordSize) != Int(viewModel.chordsize) { viewModel.chordsize = chordSize }
                    if Int(txtSize) != Int(viewModel.txtsize) { viewModel.txtsize = txtSize }
                    if Int(headerSize) != Int(viewModel.headersize) { viewModel.headersize = headerSize }
                    if isGermanNotation != viewModel.isGermanNotation { viewModel.isGermanNotation = isGermanNotation }
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
            displayMode = viewModel.displayMode
        }
    }
}
