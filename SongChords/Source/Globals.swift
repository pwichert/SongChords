//
//  Globals.swift
//  SongChords
//
//  Created by Peter Wichert on 30.12.24.
//

import SwiftUI

class IdManager {    
    private var sectionID: Int = 0
    func getSectionID() -> Int { defer { sectionID += 1 }; return sectionID }
    
    private var lineID: Int = 0
    func getLineID() -> Int { defer { lineID += 1 }; return lineID }
    
    private var textElementID: Int = 0
    func getTextElementID() -> Int { defer { textElementID += 1 }; return textElementID }
}

struct EquatableError: Equatable {
    static func == (lhs: EquatableError, rhs: EquatableError) -> Bool {
        return lhs.id == rhs.id
    }
    
    let id = UUID()
    let error: Error
}

@Observable
@MainActor
public final class Globals {
    private(set) var songChordsError: EquatableError?
    
    func setSongChordsError(error: Error) {
        songChordsError = EquatableError(error: error)
        print((songChordsError?.error as? SongChordsError)?.desc ?? songChordsError?.error.localizedDescription ?? "??")
    }
}
