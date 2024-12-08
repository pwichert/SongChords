//
//  Grundton.swift
//  SongChords Develop
//
//  Created by Peter Wichert on 03.11.24.
//

import Foundation

public enum ChordSystems: String {
    case english
    case german
    case dutch
}

public enum ChordQuality: String, CaseIterable {
    case min
    case m
    case aug
    case dim
}

public enum ChordExt: String, CaseIterable {
    case e7Sharp9Sharp11 = "7#9#11"
    case e7Sharp9Sharp5 = "7#9#5"
    case e7Sharp9Flat5 = "7#9b5"
    case e7Flat9Flat13 = "7b9b13"
    case e7Flat9Sharp11 = "7b9#11"
    case e7Flat9Flat5 = "7b9b5"
    case e7Flat9Sus = "7b9sus"
    case e7Flat9Sharp9 = "7b9#9"
    case e7Flat9Sharp5 = "7b9#5"
    case e7Flat13Sus = "7b13sus"
    case e7SusAdd3 = "7susadd3"
    case e7Flat9 = "7b9"
    case e7Flat13 = "7b13"
    case e7Sharp9 = "7#9"
    case e7Sharp11 = "7#11"
    case e7Sharp5 = "7#5"
    case e7Flat5 = "7b5"
    case e7Plus = "7+"
    case em75 = "7-5"
    case e7Alt = "7alt"
    case e7 = "7"
    case e9Sharp5 = "9#5"
    case e9Flat5 = "9b5"
    case e9Flat5Alt = "9-5"
    case e9Sus = "9sus"
    case e9Add6 = "9add6"
    case eSharp9Sharp11 = "^9#11"
    case eSharp911 = "^911"
    case e911 = "911"
    case e9Sharp11 = "9#11"
    case em9maj7 = "9maj7"
    case em9majx7 = "9^7"
    case eSharp9 = "^9"
    case e9Plus = "9+"
    case e9 = "9"
    case emaj7Sharp11 = "maj7#11"
    case emaj7Sharp5 = "maj7#5"
    case emaj7Sus2 = "maj7sus2"
    case emaj7Sus4 = "maj7sus4"
    case emaj911 = "maj911"
    case emaj13 = "maj13"
    case emaj7 = "maj7"
    case emaj9 = "maj9"
    case emajx7Sharp11 = "^7#11"
    case emajx7Sharp5 = "^7#5"
    case emajx7Sus2 = "^7sus2"
    case emajx7Sus4 = "^7sus4"
    case emajx7 = "^7"
    case e13Sharp11 = "13#11"
    case e13Sharp9 = "13#9"
    case e13Flat9 = "13b9"
    case e13Sus2 = "13sus2"
    case e13Sus4 = "13sus4"
    case emajx13 = "^13"
    case e13 = "13"
    case e6Sus2 = "6sus2"
    case e6Sus4 = "6sus4"
    case eAdd2 = "add2"
    case eAdd4 = "add4"
    case eAdd9 = "add9"
    case eSus2 = "sus2"
    case eSus4 = "sus4"
    case eSus9 = "sus9"
    case e7Sus2 = "7sus2"
    case e7Sus4 = "7sus4"
    case emSharp5 = "#5"
    case emSharp7 = "#7"
    case emb6 = "b6"
    case e11 = "11"
    case e69 = "69"
    case e6 = "6"
    case e5 = "5"
    case e4 = "4"
    case e3 = "3"
    case e2 = "2"
}

public protocol ChordRoot {
    var sharps: [ [ String ] ] { get }
    var flats: [ [ String ] ] { get }
}

private struct EnglishRoot: ChordRoot {
    public init() {}
    public let sharps = [ ["c"], ["c#"], ["d"], ["d#"], ["e"], ["f"], ["f#"], ["g"], ["g#"], ["a"], ["a#"], ["b"] ]
    public let flats = [ ["c"], ["db"], ["d"], ["eb"], ["e"], ["f"], ["gb"], ["g"], ["ab"], ["a"], ["bb"], ["b", "cb"] ]
}

private struct DutchRoot: ChordRoot {
    public init() {}
    public let sharps = [ ["c", "bis"], ["cis"], ["d"], ["dis"], ["e"], ["f", "eis"], ["fis"], ["g"], ["gis"], ["a"], ["ais"], ["b"] ]
    public let flats = [ ["c"], ["des"], ["d"], ["es", "ees"], ["e", "fes"], ["f"], ["ges"], ["g"], ["as", "aes"], ["a"], ["bes"], ["b", "ces"] ]
}

public struct EnglishDutchRoot: ChordRoot {
    public init() {}
    public let sharps = [ ["c", "bis"], ["c#", "cis"], ["d"], ["d#", "dis"], ["e"], ["f", "eis"], ["f#", "fis"], ["g"], ["g#", "gis"], ["a"], ["a#", "ais"], ["b"] ]
    public let flats = [ ["c"], ["db", "des"], ["d"], ["eb", "es", "ees"], ["e", "fes"], ["f"], ["gb", "ges"], ["g"], ["ab", "as", "aes"], ["a"], ["bb", "bes"], ["b", "cb", "ces"] ]
}

private struct GermanRoot: ChordRoot {
    public init() {}
    public let sharps = [ ["c", "his"], ["cis"], ["d"], ["dis"], ["e"], ["f", "eis"], ["fis"], ["g"], ["gis"], ["a"], ["ais"], ["h"] ]
    public let flats = [ ["c"], ["des"], ["d"], ["es", "ees"], ["e", "fes"], ["f"], ["ges"], ["g"], ["as", "aes"], ["a"], ["b"], ["h", "ces"] ]
}

public struct EnglishGermanRoot: ChordRoot {
    public init() {}
    public let sharps = [ ["c", "his"], ["cis", "c#"], ["d"], ["dis", "d#"], ["e"], ["f", "eis"], ["fis", "f#"], ["g"], ["gis", "g#"], ["a"], ["ais", "a#"], ["h"] ]
    public let flats = [ ["c"], ["des", "db"], ["d"], ["es", "ees", "eb"], ["e", "fes"], ["f"], ["ges", "gb"], ["g"], ["as", "aes", "ab"], ["a"], ["b", "bb"], ["h", "cb", "ces"] ]
}

public struct ParsedChord: Identifiable {
    public let id = UUID()
    
    // ursprünglicher Akkordtext
    public let name: String
        
    private let grundton: Int?
    private let isFlat: Bool
    
    private let quality: ChordQuality?
    private let ext: ChordExt?
    
    private let basston: Int?
    private let isBassFlat: Bool
    
    public static func parse(_ chordString: String, rootSystem: inout ChordRoot, strict: Bool) -> ParsedChord? {
        if chordString.isEmpty { return nil }
                
        // Grundton
        let str = chordString.lowercased()
        var gtIndex: Int?
        var grundtonString: String?
        var isFlat: Bool = false
        (gtIndex, grundtonString, isFlat) = findTone(tone: str, rootSystem: &rootSystem)

        if gtIndex == nil { return nil }
        
        var index = chordString.index(chordString.startIndex, offsetBy: grundtonString!.count)
        
        var quality: ChordQuality?
        if index < chordString.endIndex && !String(chordString[index...]).lowercased().starts(with: "maj") {
            quality = ChordQuality.allCases.first(where: { String(chordString[index...]).lowercased().starts(with: $0.rawValue) })
            if let quality = quality {
                index = chordString.index(index, offsetBy: quality.rawValue.count)
            }
        }
        
        var ext: ChordExt?
        if index < chordString.endIndex {
            ext = ChordExt.allCases.first(where: { String(chordString[index...]).lowercased().starts(with: $0.rawValue) })
            if let ext = ext {
                index = chordString.index(index, offsetBy: ext.rawValue.count)
            }
        }
        
        var bsIndex: Int?
        var bassFlat: Bool = false
        if index < chordString.endIndex && chordString[index] == "/" {
            index = chordString.index(index, offsetBy: 1)
            
            if index < chordString.endIndex {
                // Basston extrahieren
                var bassString: String?
                let str = chordString[index...].lowercased()
                (bsIndex, bassString, bassFlat) = findTone(tone: str, rootSystem: &rootSystem)
                index = chordString.index(index, offsetBy: bassString?.count ?? 0)
            }
            if bsIndex == nil && strict { return nil }
        }
        
        if index < chordString.endIndex && strict {
            return nil
        }
        
        return ParsedChord(name: chordString, grundton: gtIndex, isFlat: isFlat, quality: quality, ext: ext, basston: bsIndex, isBassFlat: bassFlat)
        
        func findTone(tone: String, rootSystem: inout ChordRoot) -> (Int?, String?, isFlat: Bool) {
            var idx = 0
            var sharpString: String?
            var sharpIdx: Int?
            
            for rootElem in rootSystem.sharps {
                for enharmonic in rootElem {
                    if tone.starts(with: enharmonic) && enharmonic.count > sharpString?.count ?? 0 {
                        sharpString = enharmonic
                        sharpIdx = idx
                    }
                }
                idx += 1
            }

            var flatString: String?
            var flatIdx: Int?
            idx = 0
            for rootElem in rootSystem.flats {
                for enharmonic in rootElem {
                    if tone.starts(with: enharmonic) && enharmonic.count > flatString?.count ?? 0 {
                        flatString = enharmonic
                        flatIdx = idx
                    }
                }
                idx += 1
            }

            return (flatString?.count ?? 0) > (sharpString?.count ?? 0) ? (flatIdx, flatString, true) : (sharpIdx, sharpString,false)
        }
    }
    
    public func toString(transpose: Int, rootSystem: inout ChordRoot) -> String {
        if transpose != 0 {
            let tChord = transposeChord(by: transpose, rootSystem: &rootSystem)
            
            if let tChord = tChord {
                return tChord.toString_(transpose: 0, rootSystem: &rootSystem, isTransposed: true, useFlats: transpose < 0)
            }
            
            return "?"
        }
        
        return toString_(transpose: 0, rootSystem: &rootSystem, isTransposed: false, useFlats: false)
    }
    
    private func toString_(transpose: Int, rootSystem: inout ChordRoot, isTransposed: Bool, useFlats: Bool) -> String {
        var res = ""
                
        if let grundton = grundton {
            let tone = (useFlats || isFlat ? rootSystem.flats : rootSystem.sharps)[grundton].first!.capitalized
            res.append(tone)
        }
        
        if let quality = quality {
            res.append(quality.rawValue)
        }
        
        if let ext = ext {
            res.append(ext.rawValue)
        }
        
        if let basston = basston {
            let tone = (useFlats || isBassFlat ? rootSystem.flats : rootSystem.sharps)[basston].first!.capitalized
            res.append("/" + tone)
        }
        
        return res
    }
    
    private func transposeChord(by halfSteps: Int, rootSystem: inout ChordRoot) -> ParsedChord? {
        let sharps = rootSystem.sharps
        let flats = rootSystem.flats
        
        if let grundton = grundton {
            let gTrx = transposeTone(tone: grundton, by: halfSteps)
            
            if let basston = basston {
                let bTrx = transposeTone(tone: basston, by: halfSteps)
                
                return ParsedChord(name: name, grundton: gTrx, isFlat: isFlat, quality: quality, ext: ext, basston: bTrx, isBassFlat: isBassFlat)
            }
            
            return ParsedChord(name: name, grundton: gTrx, isFlat: isFlat, quality: quality, ext: ext, basston: basston, isBassFlat: isBassFlat)
        }
        
        return nil
        
        func transposeTone(tone: Int, by halfSteps: Int) -> Int {
            let trx = halfSteps >= 0 ? sharps : flats
            let transposeVal = if halfSteps >= 0 {
                halfSteps % trx.count
            } else {
                -((-halfSteps) % trx.count)
            }
            
            return (tone + transposeVal + trx.count) % (trx.count)
        }
    }
    
    static func mergeArrays(_ seq1: [[String]], _ seq2: [[String]]) -> [[String]] {
        var merged: [[String]] = []
        
        for (seq1Group, seq2Group) in zip(seq1, seq2) {
            // Kombiniere die Subarrays, behalte die Reihenfolge und entferne Duplikate
            var combined = seq1Group
            for element in seq2Group {
                if !combined.contains(element) {
                    combined.append(element)
                }
            }
            merged.append(combined)
        }
        
        return merged
    }
}
