//
//  ChordGenerator.swift
//  SongChords
//
//  Created by Peter Wichert on 23.02.25.
//


struct ChordGenerator {
    static func barre6(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 8) % 12
        if baseFret == 0 { return [] }
        return [ChordFretVariant(base: baseFret, frets: [baseFret, baseFret + 2, baseFret + 2, baseFret + 1, baseFret, baseFret], fingers: [1,4,3,2,1,1])]
    }
    
    static func barre6Minor(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 8) % 12
        if baseFret == 0 { return [] }

        if let ext {
            switch ext {
            case ChordExt.e7: return [ChordFretVariant(base: baseFret, frets: [baseFret, baseFret + 2, baseFret, baseFret, baseFret, baseFret], fingers: [1,3,1,1,1,1])]
            default: return []
            }
        } else {
            return [ChordFretVariant(base: baseFret, frets: [baseFret, baseFret + 2, baseFret + 2, baseFret, baseFret, baseFret], fingers: [1,4,3,1,1,1])]
        }
    }
    
    static func barre5(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 3) % 12
        if baseFret == 0 { return [] }
        
        if let ext {
            switch ext {
            case ChordExt.e7: return [ChordFretVariant(base: baseFret, frets: [-1, baseFret, baseFret + 2, baseFret, baseFret + 2, baseFret], fingers: [nil,1,3,1,4,1])]
            default: return []
            }
        } else {
            return [ChordFretVariant(base: baseFret, frets: [-1, baseFret, baseFret + 2, baseFret + 2, baseFret + 2, baseFret], fingers: [nil,1,2,3,4,1])]
        }
    }
    
    static func barre5Minor(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 3) % 12
        if baseFret == 0 { return [] }
        return [ChordFretVariant(base: baseFret, frets: [-1, baseFret, baseFret + 2, baseFret + 2, baseFret + 1, baseFret], fingers: [nil,1,4,3,2,1])]
    }
    
    static func dimChord(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        return []
    }
    
    static func augChord(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        return []
    }
}
