//
//  SongTaskManager.swift
//  SongChords
//
//  Created by Peter Wichert on 10.02.25.
//

import Foundation

actor SongTaskManager {
    private var processingTask: Task<Void, Never>?
    
    public static let shared = SongTaskManager()
    
    func run(_ task: Task<Void, Never>) {
        processingTask?.cancel()
        processingTask = task
    }
    
    func processSongInBackground(representationHolder: RepresentationHolder, srcText: String, transpose: Int, userSettings: UserSettingsSendable, forPrinting: Bool) {
        self.run(Task.detached {
            // Aufgabe im Hintergrund ausführen
            let result = await self.createSongRepresentation(userSettings: userSettings, srcText: srcText, transpose: transpose, forPrinting: forPrinting)
            
            // Ergebnis auf dem Main-Thread aktualisieren
            if let result = result {
                await representationHolder.updateSongRepresentation(result)
            }
        })
    }
    
    func createSongRepresentation(userSettings: UserSettingsSendable, srcText: String, transpose: Int, forPrinting: Bool) -> SongRepresentation? {
        do {
            print("songRepresentation on \(Thread.current)")
            
            let tokens = try ChordProLexer(input: srcText).tokenize()
            if Task.isCancelled { print("lexer cancelled"); return nil }
            
            let songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: transpose, tokens: tokens, forPrinting: forPrinting).parse()
            if Task.isCancelled { print("parser cancelled"); return nil }
            
            return songRepresentation
        } catch {
            print("\(error)")
            return nil
        }
    }
}
