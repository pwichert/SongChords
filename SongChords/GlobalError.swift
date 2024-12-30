//
//  GlobalError.swift
//  SongChords
//
//  Created by Peter Wichert on 30.12.24.
//

import SwiftUI

@Observable
public final class GlobalError {
    private(set) var songChordsError: String?
    
    func setSongChordsError(error: Error) {
        if let songErr = error as? SongChordsError {
            songChordsError = songErr.description
        } else {
            songChordsError = error.localizedDescription
        }
        print(songChordsError ?? "no error")
    }
}
