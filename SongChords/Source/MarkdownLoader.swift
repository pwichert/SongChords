//
//  MarkdownLoader.swift
//  SongChords
//
//  Created by Peter Wichert on 31.01.26.
//

import SwiftUI

enum MarkdownError: LocalizedError {
    case notFound(base: String, name: String)
    case invalidEncoding(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let base, let name):
            return "Markdown file not found: \(base)/\(name).md"
        case .invalidEncoding(let name):
            return "Invalid text encoding in \(name).md"
        }
    }
}

struct MarkdownLoader {

    static func load(base: String, name: String) throws -> String {

        guard let url = Bundle.main.url(forResource: name, withExtension: "md", subdirectory: base) else {
            throw MarkdownError.notFound(base: base, name: name)
        }

        let data = try Data(contentsOf: url)

        guard let text = String(data: data, encoding: .utf8) else {
            throw MarkdownError.invalidEncoding(name)
        }

        return text
    }
}
