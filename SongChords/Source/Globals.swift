//
//  Globals.swift
//  SongChords
//
//  Created by Peter Wichert on 30.12.24.
//

import SwiftUI
import SwiftData

struct EquatableError: Equatable {
    static func == (lhs: EquatableError, rhs: EquatableError) -> Bool {
        return lhs.id == rhs.id
    }
    
    let id = UUID()
    let error: Error
}

@Observable
public final class Globals {
    private(set) var songChordsError: EquatableError?
    
    func setSongChordsError(error: Error) {
        songChordsError = EquatableError(error: error)
        print((songChordsError?.error as? SongChordsError)?.desc ?? songChordsError?.error.localizedDescription ?? "??")
    }
}

nonisolated
struct ResourceHelper {
    static let localeCode = Locale.current.language.languageCode == .german ? "de" : "en"

    static func resourceBase(base: String) -> String {
        return "AppResources/\(base)/\(ResourceHelper.localeCode)"
    }
}

nonisolated
struct GlobalFunctions {
    public static func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: round(timeInterval)) ?? "00:00"
    }

    public static func mp3Path() throws -> URL {
        let fileManager = FileManager.default
        let dest = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let destDir = dest.appendingPathComponent("mp3")
        
        if !fileManager.fileExists(atPath: destDir.path) {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        }
        
        return destDir
    }
    
    public static func isDisabled(song: Song) -> Bool {
        return song.musicItemId.isEmpty || (song.musicItemId.starts(with: "local@") && !song.mp3FileExists())
    }
}

// Global access point for a ModelContainer used by wrappers to export Files.
// Set this once during app startup, e.g., in the App struct after creating the container.
struct GlobalModelContainer {
    static var shared: ModelContainer?
}
