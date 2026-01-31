//
//  MarkdownResourceView.swift
//  SongChords
//
//  Created by Peter Wichert on 31.01.26.
//

import SwiftUI

struct MarkdownResourceView: View {
    let title: String
    let base: String
    let name: String

    @State private var nodes: [MDNode] = []
    @State private var error: String?

    var body: some View {
        InfoContentView(title) {
            if let error {
                ContentUnavailableView(
                    "Unable to load document",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(error)
                )
            } else {
                MarkdownView(nodes: nodes)
            }
        }
        .task(id: base + name) {
            load()
        }
    }

    private func load() {
        do {
            let base = ResourceHelper.resourceBase(base: base)
            let text = try MarkdownLoader.load(base: base, name: name)
            nodes = MarkdownParser.parse(text)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
