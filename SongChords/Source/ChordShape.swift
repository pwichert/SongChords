//
//  ChordShape.swift
//  SongChords
//
//  Created by Peter Wichert on 17.02.25.
//

import SwiftUI

struct ChordShape: Equatable {
    static func == (lhs: ChordShape, rhs: ChordShape) -> Bool {
        return lhs.name == rhs.name
    }
    
    let name: String
    var variants: [ChordVariant] {
        return ChordShape.chordFrets[name.lowercased()] ?? []
    }
    
    static private let chordFrets = [
        // A-Akkorde
        "a": [
            ChordVariant(base: 1, frets: [-1,0,2,2,2,0], fingers: [nil,nil,1,2,3,nil]),
            ChordVariant(base: 5, frets: [5,7,7,6,5,5], fingers: [1,3,4,2,1,1])
        ],
        "am": [
            ChordVariant(base: 1, frets: [-1,0,2,2,1,0], fingers: [nil,nil,2,3,1,nil]),
            ChordVariant(base: 5, frets: [5,7,7,5,5,5], fingers: [1,3,4,1,1,1])
        ],
        "a7": [
            ChordVariant(base: 1, frets: [-1,0,2,0,2,0], fingers: [nil,nil,2,nil,3,nil]),
            ChordVariant(base: 5, frets: [5,7,5,6,5,5], fingers: [1,3,1,2,1,1])
        ],
        "am7": [
            ChordVariant(base: 1, frets: [-1,0,2,0,1,0], fingers: [nil,nil,2,nil,1,nil]),
            ChordVariant(base: 5, frets: [5,7,5,5,5,5], fingers: [1,3,1,1,1,1])
        ],
        "a6": [
            ChordVariant(base: 1, frets: [-1,0,2,2,2,2], fingers: [nil,nil,1,2,3,4]),
            ChordVariant(base: 5, frets: [5,7,7,6,7,5], fingers: [1,3,4,2,4,1])
        ],

        // B-Akkorde
        "b": [
            ChordVariant(base: 1, frets: [-1,2,4,4,4,2], fingers: [nil,1,3,3,3,1])
        ],
        "bm": [
            ChordVariant(base: 1, frets: [-1,2,4,4,3,2], fingers: [nil,1,3,4,2,1])
        ],
        "b7": [
            ChordVariant(base: 1, frets: [-1,2,1,2,0,2], fingers: [nil,2,1,3,nil,4])
        ],
        "bm7": [
            ChordVariant(base: 1, frets: [-1,2,0,2,0,2], fingers: [nil,2,nil,3,nil,4])
        ],
        "b6": [
            ChordVariant(base: 1, frets: [-1,2,4,4,4,4], fingers: [nil,1,3,3,3,3])
        ],

        // C-Akkorde
        "c": [
            ChordVariant(base: 1, frets: [-1,3,2,0,1,0], fingers: [nil,3,2,nil,1,nil])
        ],
        "cm": [
            ChordVariant(base: 3, frets: [-1,3,5,5,4,3], fingers: [nil,1,3,4,2,1])
        ],
        "c7": [
            ChordVariant(base: 1, frets: [-1,3,2,3,1,0], fingers: [nil,3,2,1,4,nil])
        ],
        "cm7": [
            ChordVariant(base: 3, frets: [-1,3,5,3,4,3], fingers: [nil,1,3,1,2,1])
        ],
        "c6": [
            ChordVariant(base: 1, frets: [-1,3,2,2,1,0], fingers: [nil,3,2,1,1,nil])
        ],

        // D-Akkorde
        "d": [
            ChordVariant(base: 1, frets: [-1,-1,0,2,3,2], fingers: [nil,nil,nil,1,3,2])
        ],
        "dm": [
            ChordVariant(base: 1, frets: [-1,-1,0,2,3,1], fingers: [nil,nil,nil,2,3,1])
        ],
        "d7": [
            ChordVariant(base: 1, frets: [-1,-1,0,2,1,2], fingers: [nil,nil,nil,2,1,3])
        ],
        "dm7": [
            ChordVariant(base: 1, frets: [-1,-1,0,2,1,1], fingers: [nil,nil,nil,2,1,1])
        ],
        "d6": [
            ChordVariant(base: 1, frets: [-1,-1,0,2,0,2], fingers: [nil,nil,nil,2,nil,3])
        ],

        // E-Akkorde
        "e": [
            ChordVariant(base: 1, frets: [0,2,2,1,0,0], fingers: [nil,2,3,1,nil,nil])
        ],
        "em": [
            ChordVariant(base: 1, frets: [0,2,2,0,0,0], fingers: [nil,2,3,nil,nil,nil])
        ],
        "e7": [
            ChordVariant(base: 1, frets: [0,2,0,1,0,0], fingers: [nil,2,nil,1,nil,nil])
        ],
        "em7": [
            ChordVariant(base: 1, frets: [0,2,0,0,0,0], fingers: [nil,2,nil,nil,nil,nil])
        ],
        "e6": [
            ChordVariant(base: 1, frets: [0,2,2,1,2,0], fingers: [nil,2,3,1,4,nil])
        ],

        // F-Akkorde
        "f": [
            ChordVariant(base: 1, frets: [1,3,3,2,1,1], fingers: [1,3,4,2,1,1])
        ],
        "fm": [
            ChordVariant(base: 1, frets: [1,3,3,1,1,1], fingers: [1,3,4,1,1,1])
        ],
        "f7": [
            ChordVariant(base: 1, frets: [1,3,1,2,1,1], fingers: [1,3,1,2,1,1])
        ],
        "fm7": [
            ChordVariant(base: 1, frets: [1,3,1,1,1,1], fingers: [1,3,1,1,1,1])
        ],
        "f6": [
            ChordVariant(base: 1, frets: [1,3,3,2,3,1], fingers: [1,3,4,2,4,1])
        ],

        // G-Akkorde
        "g": [
            ChordVariant(base: 1, frets: [3,2,0,0,0,3], fingers: [2,1,nil,nil,nil,3])
        ],
        "gm": [
            ChordVariant(base: 3, frets: [3,5,5,3,3,3], fingers: [1,3,4,1,1,1])
        ],
        "g7": [
            ChordVariant(base: 1, frets: [3,2,0,0,0,1], fingers: [3,2,nil,nil,nil,1])
        ],
        "gm7": [
            ChordVariant(base: 3, frets: [3,5,3,3,3,3], fingers: [1,3,1,1,1,1])
        ],
        "g6": [
            ChordVariant(base: 1, frets: [3,2,0,0,0,0], fingers: [3,2,nil,nil,nil,nil])
        ]
    ]
}

struct ChordVariant {
    let base: Int       // fretoffset
    let frets: [Int]  // -1 = nicht spielen, 0 = offene Saite, 1-22 = Bund
    let fingers: [Int?]  // Finger, die die Saiten greifen (optional)
}
