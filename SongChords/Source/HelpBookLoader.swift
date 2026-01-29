//
//  Help.swift
//  SongChords
//
//  Created by Peter Wichert on 26.01.26.
//

import SwiftUI

struct HelpChapter: Identifiable, Hashable, Decodable {
    let id: String
    let title: String
    let file: String
}

@Observable
final class HelpBookLoader {
    let initialChapter: String?
    
    var chapters: [HelpChapter] = []
    var currentID: HelpChapter.ID?

    private let base: String

    init(initialChapter: String?) {
        self.initialChapter = initialChapter
        self.base = ResourceHelper.helpBase()
    }
    
    func load() {
        
        guard
            let tocURL = Bundle.main.url(forResource: "toc", withExtension: "json", subdirectory: base),
            let data = try? Data(contentsOf: tocURL),
            let items = try? JSONDecoder().decode([HelpChapter].self, from: data)
        else { return }

        chapters = items
        
        if let initialChapter {
            currentID = items.first(where: { $0.id == initialChapter} )?.id
        } else {
            #if os(macOS)
            currentID = items.first?.id
            #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                currentID = nil
            } else {
                currentID = items.first?.id
            }
            #endif
        }
    }

    func loadMarkdown(_ chapter: HelpChapter) -> String {
        guard
            let url = Bundle.main.url(forResource: chapter.file.replacingOccurrences(of: ".md", with: ""),
                                      withExtension: "md",
                                      subdirectory: base),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "# Not Found"
        }
        return text
    }
}
