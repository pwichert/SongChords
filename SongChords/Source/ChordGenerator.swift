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
            break
        case .dim:
            break
        case nil:
            res.append(contentsOf: ChordGenerator.barre6(grundton: grundton, ext: ext))
            res.append(contentsOf: ChordGenerator.barre5(grundton: grundton, ext: ext))
        }
        
        return res
    }
    
    static func nonBarre(grundton: Int, quality: ChordQuality?, ext: ChordExt?, basston: Int?) -> [ChordFretVariant] {
        var res: [ChordFretVariant] = []

        let minor = quality == ChordQuality.min || quality == ChordQuality.m

        // nicht durch Barre erzeugte
        switch grundton {
        case 0:
            // C
            if quality == nil && ext == nil && basston == nil {
                res.append(ChordFretVariant(base: 1, frets: [-1,3,2,0,1,0], fingers: [nil,3,2,nil,1,nil]))
                res.append(ChordFretVariant(base: 1, frets: [-1,3,2,0,1,3], fingers: [nil,3,2,nil,1,4]))
            }
            // Csus2
            if quality == nil && ext == ChordExt.eSus2 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,3,0,0,1,-1], fingers: [nil,3,nil,nil,1,nil])
            )}
            // Csus4
            if quality == nil && ext == ChordExt.eSus4 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,3,3,0,1,-1], fingers: [nil,3,4,nil,1,nil])
            )}
            // Cmaj7
            if quality == nil && ext == ChordExt.emaj7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,3,2,0,0,0], fingers: [nil,3,4,nil,nil,nil])
            )}
        case 2:
            // D7
            if quality == nil && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,2,1,2], fingers: [nil,nil,nil,2,1,3])
            )}
            // Dm7
            if minor && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,2,1,1], fingers: [nil,nil,nil,2,1,1])
            )}
            // Dsus2
            if quality == nil && ext == ChordExt.eSus2 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,2,3,0], fingers: [nil,nil,nil,1,3,nil])
            )}
            // Dsus4
            if quality == nil && ext == ChordExt.eSus4 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,2,3,3], fingers: [nil,nil,nil,1,3,4])
            )}
            // Dmaj7
            if quality == nil && ext == ChordExt.emaj7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,2,2,2], fingers: [nil,nil,nil,1,1,1])
            )}
            // D/F#
            if quality == nil && ext == nil && basston == 6 { res.append(
                ChordFretVariant(base: 1, frets: [2,-1,0,2,3,2], fingers: [0,nil,nil,1,3,2])
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
            // Esus2
            if quality == nil && ext == ChordExt.eSus2 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [0,2,4,4,0,0], fingers: [nil,1,3,4,nil,nil])
            )}
            // Esus4
            if quality == nil && ext == ChordExt.eSus4 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [0,2,2,2,0,0], fingers: [nil,1,2,3,nil,nil])
            )}
            // Emaj7
            if quality == nil && ext == ChordExt.emaj7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [0,2,1,1,0,0], fingers: [nil,3,1,2,nil,nil])
            )}
            // Em/D
            if minor && ext == nil && basston == 2 { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,0,0,0,0], fingers: [nil,nil,nil,nil,nil,nil])
            )}
        case 5:
            // Fsus2
            if quality == nil && ext == ChordExt.eSus2 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,3,0,1,1], fingers: [nil,nil,4,nil,1,1])
            )}
            // Fsus4
            if quality == nil && ext == ChordExt.eSus4 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,3,3,1,1], fingers: [nil,nil,4,3,1,1])
            )}
            // Fmaj7
            if quality == nil && ext == ChordExt.emaj7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,-1,3,2,1,0], fingers: [nil,nil,3,2,1,nil])
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
            // Gsus2
            if quality == nil && ext == ChordExt.eSus2 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [3,0,0,0,3,3], fingers: [1,nil,nil,nil,3,4])
            )}
            // Gsus4
            if quality == nil && ext == ChordExt.eSus4 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [3,-1,0,0,1,3], fingers: [3,nil,nil,nil,1,4])
            )}
            // Gmaj7
            if quality == nil && ext == ChordExt.emaj7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [3,2,0,0,0,2], fingers: [3,1,nil,nil,nil,4])
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
            // Asus2
            if quality == nil && ext == ChordExt.eSus2 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,0,2,2,0,0], fingers: [nil,nil,2,3,nil,nil])
            )}
            // Asus4
            if quality == nil && ext == ChordExt.eSus4 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,0,2,2,3,0], fingers: [nil,nil,1,2,3,nil])
            )}
            // Amaj7
            if quality == nil && ext == ChordExt.emaj7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,0,2,1,2,0], fingers: [nil,nil,1,2,3,nil])
            )}
            // A/F#
            if quality == nil && ext == nil && basston == 6 { res.append(
                ChordFretVariant(base: 1, frets: [2,0,2,2,2,0], fingers: [0,nil,1,2,3,nil])
            )}
        case 11:
            // B7
            if quality == nil && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,2,1,2,0,2], fingers: [nil,2,1,3,nil,4])
            )}
            // Bm7
            if minor && ext == ChordExt.e7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,2,0,2,0,2], fingers: [nil,1,nil,2,nil,3])
            )}
            // Bsus2
            if quality == nil && ext == ChordExt.eSus2 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,2,4,4,2,2], fingers: [nil,1,3,4,1,1])
            )}
            // Bsus4
            if quality == nil && ext == ChordExt.eSus4 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,2,4,4,0,0], fingers: [nil,1,3,4,nil,nil])
            )}
            // Bmaj7
            if quality == nil && ext == ChordExt.emaj7 && basston == nil { res.append(
                ChordFretVariant(base: 1, frets: [-1,2,1,3,0,-1], fingers: [nil,2,1,4,nil,nil])
            )}
        default: break
        }
        
        return res
    }
    
    // Bildet alle Akkorde ab, auch die mit 0-tem Bund. Der 0-te Bund wird im Diagramm nicht berücksichtigt
    static func movableChord(grundton: Int, quality: ChordQuality?, ext: ChordExt?, basston: Int?) -> [ChordFretVariant] {
        var res: [ChordFretVariant] = []

        let minor = quality == ChordQuality.min || quality == ChordQuality.m

        // D-Shape Dreiklang
        if quality == nil && ext == nil && basston == nil {
            let baseFret = (grundton - 1) % 12
            let gtFret = grundton == 2 ? 0 : -1
            res.append(ChordFretVariant(base: max(1,baseFret), frets: [-1, -1, gtFret, baseFret + 1,baseFret + 2,baseFret + 1], fingers: [nil,nil,nil,1,3,2])
        )}

        // Dm-Shape Dreiklang
        if minor && ext == nil && basston == nil {
            let baseFret = (grundton - 1) % 12
            let gtFret = grundton == 2 ? 0 : -1
            res.append(ChordFretVariant(base: max(1,baseFret), frets: [-1, -1, gtFret, baseFret + 1,baseFret + 2,baseFret], fingers: [nil,nil,nil,2,3,1])
        )}

        // maj7
        if quality == nil && ext == ChordExt.emaj7 && basston == nil {
            let baseFret = (grundton + 3) % 12
            res.append(ChordFretVariant(base: max(1,baseFret), frets: [-1, baseFret, baseFret + 2, baseFret + 1, baseFret + 2, baseFret], fingers: [nil,1,3,2,4,1]))
        }

        // 6
        if quality == nil && ext == ChordExt.e6 && basston == nil {
            let baseFret = (grundton + 1) % 12
            res.append(ChordFretVariant(base: max(1,baseFret), frets: [-1, -1, baseFret + 2, baseFret + 1, baseFret + 2, baseFret], fingers: [1,1,3,2,4,1]))
        }

        // m6
        if minor && ext == ChordExt.e6 && basston == nil {
            let baseFret = (grundton + 1) % 12
            res.append(ChordFretVariant(base: max(1,baseFret), frets: [baseFret, baseFret + 2, baseFret + 2, baseFret, baseFret + 2, baseFret], fingers: [1,2,3,1,4,1]))
        }

        // 9
        if quality == nil && ext == ChordExt.e9 && basston == nil {
            let baseFret = (grundton + 1) % 12
            res.append(ChordFretVariant(base: max(1,baseFret), frets: [-1, baseFret + 2, baseFret + 1, baseFret + 2, baseFret + 2, baseFret + 2], fingers: [1,2,1,3,3,3]))
        }

        // Dim
        if quality == ChordQuality.dim && ext == nil && basston == nil {
            let baseFret = (grundton + 3) % 12
            res.append(ChordFretVariant(base: max(1,baseFret), frets: [-1, baseFret, baseFret + 1, baseFret + 2, baseFret + 1, -1], fingers: [nil,1,2,4,3,nil]))
        }

        // Aug
        if quality == ChordQuality.aug && ext == nil && basston == nil {
            let baseFret = (grundton + 1) % 12
            res.append(ChordFretVariant(base: max(1,baseFret), frets: [-1, baseFret + 2, baseFret + 1, baseFret, baseFret, -1], fingers: [nil,4,3,1,2,nil]))
        }

        return res
    }
    
    static private func barre6(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 8) % 12
        if baseFret == 0 { return [] }
        
        if let ext {
            switch ext {
            case ChordExt.e7: return [ChordFretVariant(base: baseFret, frets: [baseFret, baseFret + 2, baseFret, baseFret + 1, baseFret, baseFret], fingers: [1,3,1,2,1,1])]
            case ChordExt.eSus4: return [ChordFretVariant(base: baseFret, frets: [baseFret, baseFret, baseFret + 2, baseFret + 2, baseFret, baseFret], fingers: [1,1,3,4,1,1])]
            default: return []
            }
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
        
    static private func barre5(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 3) % 12
        if baseFret == 0 { return [] }
        
        // Bei E/Em mit Grundton == 4 darf Leerseite klingen
        let gtFret = grundton == 4 ? 0 : -1
        
        if let ext {
            switch ext {
            case ChordExt.e7: return [ChordFretVariant(base: baseFret, frets: [gtFret, baseFret, baseFret + 2, baseFret, baseFret + 2, baseFret], fingers: [nil,1,3,1,4,1])]
            default: return []
            }
        } else {
            return [ChordFretVariant(base: baseFret, frets: [gtFret, baseFret, baseFret + 2, baseFret + 2, baseFret + 2, baseFret], fingers: [nil,1,2,3,4,1])]
        }
    }
    
    static private func barre5Minor(grundton: Int, ext: ChordExt?) -> [ChordFretVariant] {
        let baseFret = (grundton + 3) % 12
        if baseFret == 0 { return [] }
        
        // Bei E/Em mit Grundton == 4 darf Leerseite klingen
        let gtFret = grundton == 4 ? 0 : -1

        if let ext {
            switch ext {
            case ChordExt.e7: return [ChordFretVariant(base: baseFret, frets: [gtFret, baseFret, baseFret + 2, baseFret, baseFret + 1, baseFret], fingers: [nil,1,3,1,2,1])]
            default: return []
            }
        } else {
            return [ChordFretVariant(base: baseFret, frets: [gtFret, baseFret, baseFret + 2, baseFret + 2, baseFret + 1, baseFret], fingers: [nil,1,3,4,2,1])]
        }
    }
}
