//
//  ChordGenerator.swift
//  SongChords
//
//  Created by Peter Wichert on 23.02.25.
//


struct ChordGenerator {
    static func barre(grundton: Int, quality: ChordQuality?, ext: ChordExt?, basston: Int?) -> [ChordFretVariant] {
        var res: [ChordFretVariant] = []

        // geht noch nicht
        guard basston == nil else { return [] }

        // Barre-Schema
        switch quality {
        case .min, .m:
            res.append(contentsOf: ChordGenerator.barre6Minor(grundton: grundton, ext: ext))
            res.append(contentsOf: ChordGenerator.barre5Minor(grundton: grundton, ext: ext))
        case .aug:
            return ChordGenerator.augChord(grundton: grundton, ext: ext)
        case .dim:
            return ChordGenerator.dimChord(grundton: grundton, ext: ext)
        case nil:
            res.append(contentsOf: ChordGenerator.barre6(grundton: grundton, ext: ext))
            res.append(contentsOf: ChordGenerator.barre5(grundton: grundton, ext: ext))
        }
        
        return res
    }
    
    static func nonBarre(grundton: Int, quality: ChordQuality?, ext: ChordExt?, basston: Int?) -> [ChordFretVariant] {
        var res: [ChordFretVariant] = []

        // geht noch nicht
        guard basston == nil else { return [] }

        let minor = quality == ChordQuality.min || quality == ChordQuality.m

        // nicht durch Barre erzeugte
        switch grundton {
        case 0:
            // C
            if quality == nil && ext == nil && basston == nil {
                res.append(ChordFretVariant(base: 1, frets: [-1,3,2,0,1,0], fingers: [nil,3,2,nil,1,nil]))
                res.append(ChordFretVariant(base: 1, frets: [-1,3,2,0,1,3], fingers: [nil,3,2,nil,1,4]))
            }
        case 2:
            // D
            if quality == nil && ext == nil && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,2,3,2], fingers: [nil,nil,nil,1,3,2])
            )}
            // Dm
            if minor && ext == nil && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,2,3,1], fingers: [nil,nil,nil,2,3,1])
            )}
            // D7
            if quality == nil && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,2,1,2], fingers: [nil,nil,nil,2,1,3])
            )}
            // Dm7
            if minor && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,2,1,1], fingers: [nil,nil,nil,2,1,1])
            )}
        case 4:
            // E
            if quality == nil && ext == nil && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [0,2,2,1,0,0], fingers: [nil,2,3,1,nil,nil])
            )}
            // E7
            if quality == nil && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [0,2,0,1,0,0], fingers: [nil,2,nil,1,nil,nil])
            )}
            // Em
            if minor && ext == nil && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [0,2,2,0,0,0], fingers: [nil,2,3,nil,nil,nil])
            )}
            // Em7
            if minor && ext == ChordExt.e7 && basston == nil {
                res.append(ChordFretVariant(base: 1, frets: [0,2,0,0,0,0], fingers: [nil,1,nil,nil,nil,nil]))
                res.append(ChordFretVariant(base: 1, frets: [0,2,0,0,3,0], fingers: [nil,1,nil,nil,2,nil]))
                res.append(ChordFretVariant(base: 1, frets: [0,2,2,0,3,0], fingers: [nil,1,2,nil,3,nil]))
                res.append(ChordFretVariant(base: 1, frets: [0,2,2,0,3,3], fingers: [nil,1,2,nil,3,4]))
            }
        case 5:
            // F7
            if quality == nil && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [1,3,1,2,1,1], fingers: [1,3,1,2,1,1])
            )}
        case 7:
            // G
            if quality == nil && ext == nil && basston == nil {
                res.append(ChordFretVariant(base: 1, frets: [3,2,0,0,0,3], fingers: [2,1,nil,nil,nil,4]))
                res.append(ChordFretVariant(base: 1, frets: [3,2,0,0,3,3], fingers: [2,1,nil,nil,3,4]))
            }
            // G7
            if quality == nil && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [3,2,0,0,0,1], fingers: [3,2,nil,nil,nil,1])
            )}
        case 9:
            // A
            if quality == nil && ext == nil && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,0,2,2,2,0], fingers: [nil,nil,1,2,3,nil])
            )}
            // A7
            if quality == nil && ext == ChordExt.e7 && basston == nil {
                res.append(ChordFretVariant(base: 1, frets: [-1,0,2,0,2,0], fingers: [nil,nil,1,nil,2,nil]))
                res.append(ChordFretVariant(base: 1, frets: [-1,0,2,0,2,3], fingers: [nil,nil,1,nil,2,3]))
                res.append(ChordFretVariant(base: 1, frets: [-1,0,2,2,2,3], fingers: [nil,nil,1,2,3,4]))
            }
            // Am
            if minor && ext == nil && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,0,2,2,1,0], fingers: [nil,nil,2,3,1,nil])
            )}
            // Am7
            if minor && ext == ChordExt.e7 && basston == nil {
                res.append(ChordFretVariant(base: 1, frets: [-1,0,2,0,1,0], fingers: [nil,nil,2,nil,1,nil]))
                res.append(ChordFretVariant(base: 1, frets: [-1,0,2,0,1,3], fingers: [nil,nil,2,nil,1,3]))
            }
        case 11:
            // B7
            if quality == nil && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,2,1,2,0,2], fingers: [nil,2,1,3,nil,4])
            )}
            // Bm7
            if minor && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,2,0,2,0,2], fingers: [nil,1,nil,2,nil,3])
            )}
        default: break
        }
        
        return res
    }
    
    static private func barre6(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 8) % 12
        if baseFret == 0 { return [] }
        
        if let ext {
            return []
        } else {
            return [ChordFretVariant(base: baseFret, frets: [baseFret, baseFret + 2, baseFret + 2, baseFret + 1, baseFret, baseFret], fingers: [1,3,4,2,1,1])]
        }
    }
    
    static private func barre6Minor(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 8) % 12
        if baseFret == 0 { return [] }

        if let ext {
            switch ext {
            case ChordExt.e7: return [ChordFretVariant(base: baseFret, frets: [baseFret, baseFret + 2, baseFret, baseFret, baseFret, baseFret], fingers: [1,3,1,1,1,1])]
            default: return []
            }
        } else {
            return [ChordFretVariant(base: baseFret, frets: [baseFret, baseFret + 2, baseFret + 2, baseFret, baseFret, baseFret], fingers: [1,3,4,1,1,1])]
        }
    }
    
    // Bei E/Em mit Grundton == 4 darf Leerseite klingen
    
    static private func barre5(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 3) % 12
        if baseFret == 0 { return [] }
        
        if let ext {
            switch ext {
            case ChordExt.e7: return [ChordFretVariant(base: baseFret, frets: [grundton == 4 ? 0 : -1, baseFret, baseFret + 2, baseFret, baseFret + 2, baseFret], fingers: [nil,1,3,1,4,1])]
            default: return []
            }
        } else {
            return [ChordFretVariant(base: baseFret, frets: [grundton == 4 ? 0 : -1, baseFret, baseFret + 2, baseFret + 2, baseFret + 2, baseFret], fingers: [nil,1,2,3,4,1])]
        }
    }
    
    static private func barre5Minor(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 3) % 12
        if baseFret == 0 { return [] }
        
        if let ext {
            return []
        } else {
            return [ChordFretVariant(base: baseFret, frets: [grundton == 4 ? 0 : -1, baseFret, baseFret + 2, baseFret + 2, baseFret + 1, baseFret], fingers: [nil,1,3,4,2,1])]
        }
    }
    
    static private func dimChord(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        return []
    }
    
    static private func augChord(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        return []
    }
}
