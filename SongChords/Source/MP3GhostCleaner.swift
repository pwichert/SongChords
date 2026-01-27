//
//  GhostMP3.swift
//  SongChords
//
//  Created by Peter Wichert on 26.01.26.
//

import SwiftUI
import SwiftData
import OSLog

struct GhostMP3 {
    let url: URL
    let size: Int64
}

final class MP3GhostCleaner {

    static func findGhosts(in directory: URL, referencedIDs: Set<String>) throws -> [GhostMP3] {
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var ghosts: [GhostMP3] = []

        for file in files where file.pathExtension.lowercased() == "mp3" {
            let id = file.deletingPathExtension().lastPathComponent

            if !referencedIDs.contains(id) {
                let values = try file.resourceValues(forKeys: [.fileSizeKey])
                ghosts.append(GhostMP3(url: file, size: Int64(values.fileSize ?? 0)))
            }
        }
        
        return ghosts
    }

    static func delete(_ ghosts: [GhostMP3]) throws {
        for g in ghosts {
            try FileManager.default.removeItem(at: g.url)
        }
    }
    
    func runGhostScanIfNeeded() async {
        let last = UserDefaults.standard.double(forKey: "lastGhostScan")
        let now = Date().timeIntervalSince1970

        if now - last < 7 * 24 * 3600 { return } // 1 Woche

        UserDefaults.standard.set(now, forKey: "lastGhostScan")

        print("Ghostscan gestarted")
        _ = await runGhostScan()
        print("Ghostscan beendet")
    }
    
    func runGhostScan() async -> Bool {
        let ghostLog = Logger(subsystem: "com.wichert.songchords", category: "MP3GhostCleaner")

        do {
            guard let modelContainer = GlobalModelContainer.shared else { return false }
            let modelContext = modelContainer.mainContext
            
            let descriptor = FetchDescriptor<Song>()
            let songs = try modelContext.fetch(descriptor)
            
            let usedIDs: Set<String> = Set(
                try songs.compactMap { song in
                    song.musicItemId.starts(with: "local@")
                    ? try song.getMP3FileInfo()
                    : nil
                }
            )
            
            let mp3Dir = try GlobalFunctions.mp3Path()
            let ghosts = try MP3GhostCleaner.findGhosts(in: mp3Dir, referencedIDs: usedIDs)
            
            ghosts.forEach { print("ghost: \($0.url.lastPathComponent) \($0.size)") }
            try MP3GhostCleaner.delete(ghosts)
            ghostLog.info("Ghost MP3 scan successfully finished: \(ghosts.count) ghosts deleted")
            return true
        } catch is CancellationError {
            print("Ghost scan cancelled")
            return false
        } catch {
            print("Ghost scan failed:", error)
            ghostLog.error("Ghost MP3 scan failed: \(error.localizedDescription)")
            return false
        }
    }
}
