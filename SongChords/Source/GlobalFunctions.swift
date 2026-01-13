//
//  GlobalFunctions.swift
//  SongChords
//
//  Created by Peter Wichert on 31.01.25.
//

import SwiftUI
import SwiftData

nonisolated
public class GlobalFunctions {
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
