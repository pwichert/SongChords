//
//  Globals.swift
//  SongChords
//
//  Created by Peter Wichert on 30.12.24.
//

import SwiftUI

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
