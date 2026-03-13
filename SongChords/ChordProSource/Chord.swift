//
//  Grundton.swift
//  SongChords Develop
//
//  Created by Peter Wichert on 03.11.24.
//

import SwiftUI

//public enum ChordQuality: String, CaseIterable, Sendable {
//    case min
//    case m
//    case aug
//    case dim
//}
//
//public enum ChordExt: String, CaseIterable, Sendable {
//    case e7Sharp9Sharp11 = "7#9#11"
//    case e7Sharp9Sharp5 = "7#9#5"
//    case e7Sharp9Flat5 = "7#9b5"
//    case e7Flat9Flat13 = "7b9b13"
//    case e7Flat9Sharp11 = "7b9#11"
//    case e7Flat9Flat5 = "7b9b5"
//    case e7Flat9Sus = "7b9sus"
//    case e7Flat9Sharp9 = "7b9#9"
//    case e7Flat9Sharp5 = "7b9#5"
//    case e7Flat13Sus = "7b13sus"
//    case e7SusAdd3 = "7susadd3"
//    case e7Flat9 = "7b9"
//    case e7Flat13 = "7b13"
//    case e7Sharp9 = "7#9"
//    case e7Sharp11 = "7#11"
//    case e7Sharp5 = "7#5"
//    case e7Flat5 = "7b5"
//    case e7Plus = "7+"
//    case em75 = "7-5"
//    case e7Alt = "7alt"
//    case e7 = "7"
//    case e9Sharp5 = "9#5"
//    case e9Flat5 = "9b5"
//    case e9Flat5Alt = "9-5"
//    case e9Sus = "9sus"
//    case e9Add6 = "9add6"
//    case eSharp9Sharp11 = "^9#11"
//    case eSharp911 = "^911"
//    case e911 = "911"
//    case e9Sharp11 = "9#11"
//    case em9maj7 = "9maj7"
//    case em9majx7 = "9^7"
//    case eSharp9 = "^9"
//    case e9Plus = "9+"
//    case e9 = "9"
//    case emaj7Sharp11 = "maj7#11"
//    case emaj7Sharp5 = "maj7#5"
//    case emaj7Sus2 = "maj7sus2"
//    case emaj7Sus4 = "maj7sus4"
//    case emaj911 = "maj911"
//    case emaj13 = "maj13"
//    case emaj7 = "maj7"
//    case emaj9 = "maj9"
//    case emajx7Sharp11 = "^7#11"
//    case emajx7Sharp5 = "^7#5"
//    case emajx7Sus2 = "^7sus2"
//    case emajx7Sus4 = "^7sus4"
//    case emajx7 = "^7"
//    case e13Sharp11 = "13#11"
//    case e13Sharp9 = "13#9"
//    case e13Flat9 = "13b9"
//    case e13Sus2 = "13sus2"
//    case e13Sus4 = "13sus4"
//    case emajx13 = "^13"
//    case e13 = "13"
//    case e6Add9 = "6add9"
//    case e6Sus2 = "6sus2"
//    case e6Sus4 = "6sus4"
//    case eAdd2 = "add2"
//    case eAdd4 = "add4"
//    case eAdd9 = "add9"
//    case eAdd11 = "add11"
//    case eAdd13 = "add13"
//    case eSus2 = "sus2"
//    case eSus4 = "sus4"
//    case eSus9 = "sus9"
//    case e7Sus2 = "7sus2"
//    case e7Sus4 = "7sus4"
//    case emSharp5 = "#5"
//    case emSharp7 = "#7"
//    case emb6 = "b6"
//    case e11 = "11"
//    case e69 = "69"
//    case e6 = "6"
//    case e5 = "5"
//    case e4 = "4"
//    case e3 = "3"
//    case e2 = "2"
//}
//
//nonisolated
//public protocol ChordRoot {
//    var sharps: [ [ String ] ] { get }
//    var flats: [ [ String ] ] { get }
//}
//
//nonisolated
//private struct EnglishRoot: ChordRoot {
//    public init() {}
//    public let sharps = [ ["c"], ["c#"], ["d"], ["d#"], ["e"], ["f"], ["f#"], ["g"], ["g#"], ["a"], ["a#"], ["b"] ]
//    public let flats = [ ["c"], ["db"], ["d"], ["eb"], ["e"], ["f"], ["gb"], ["g"], ["ab"], ["a"], ["bb"], ["b", "cb"] ]
//}
//
//nonisolated
//private struct DutchRoot: ChordRoot {
//    public init() {}
//    public let sharps = [ ["c", "bis"], ["cis"], ["d"], ["dis"], ["e"], ["f", "eis"], ["fis"], ["g"], ["gis"], ["a"], ["ais"], ["b"] ]
//    public let flats = [ ["c"], ["des"], ["d"], ["es", "ees"], ["e", "fes"], ["f"], ["ges"], ["g"], ["as", "aes"], ["a"], ["bes"], ["b", "ces"] ]
//}
//
//nonisolated
//public struct EnglishDutchRoot: ChordRoot {
//    public init() {}
//    public let sharps = [ ["c", "bis"], ["c#", "cis"], ["d"], ["d#", "dis"], ["e"], ["f", "eis"], ["f#", "fis"], ["g"], ["g#", "gis"], ["a"], ["a#", "ais"], ["b", "h"] ]
//    public let flats = [ ["c"], ["db", "des"], ["d"], ["eb", "es", "ees"], ["e", "fes"], ["f"], ["gb", "ges"], ["g"], ["ab", "as", "aes"], ["a"], ["bb", "bes"], ["b", "cb", "ces", "h"] ]
//}
//
//nonisolated
//private struct GermanRoot: ChordRoot {
//    public init() {}
//    public let sharps = [ ["c", "his"], ["cis"], ["d"], ["dis"], ["e"], ["f", "eis"], ["fis"], ["g"], ["gis"], ["a"], ["ais"], ["h"] ]
//    public let flats = [ ["c"], ["des"], ["d"], ["es", "ees"], ["e", "fes"], ["f"], ["ges"], ["g"], ["as", "aes"], ["a"], ["b"], ["h", "ces"] ]
//}
//
//nonisolated
//public struct EnglishGermanRoot: ChordRoot {
//    public init() {}
//    public let sharps = [ ["c", "his"], ["cis", "c#"], ["d"], ["dis", "d#"], ["e"], ["f", "eis"], ["fis", "f#"], ["g"], ["gis", "g#"], ["a"], ["ais", "a#"], ["h"] ]
//    public let flats = [ ["c"], ["des", "db"], ["d"], ["es", "ees", "eb"], ["e", "fes"], ["f"], ["ges", "gb"], ["g"], ["as", "aes", "ab"], ["a"], ["b", "bb"], ["h", "cb", "ces"] ]
//}
//
///// ChordRoot Arrays "sharps" und "flats"
/////
///// Jedes SubArray ist eine Sequenz von Synonymen für die jeweilige Tonstufe. Der erste Eintrag erscheint bei der Darstellung für dieses Rootsystem,
///// das gesamte SubArray wird als Suchmuster für die Tonstufe verwendet.
/////
///// Darstellung nach Transponieren: positiv verwendet das "sharps"-Array, negativ das "flats"-Array
/////
///// International/Common
///// EnglishDutchRoot: steht für das englische System (A, A#, B, Bb ...) mit dutch Erweiterung (Bis, Bes, B ...).
/////
///// Deutsch
///// EnglichGermanRoot: steht für das deutsche System (His, B, H ...) mit english Erweiterung (A, A#, B, Bb ...).
/////
//
//
//nonisolated
//public struct ParsedChord: Identifiable, Equatable, Sendable {
//    public let id = UUID()
//    
//    // ursprünglicher Akkordtext
//    public let name: String
//        
//    // Akkordgrundtonwert: Tonstufe und sharps/flats-Array
//    private let grundton: Int?
//    private let isFlat: Bool
//        
//    private let quality: ChordQuality?
//    private let ext: ChordExt?
//    
//    // Akkordbasstonwert: Tonstufe und sharps/flats-Array
//    private let basston: Int?
//    private let isBassFlat: Bool
//    
////    func getFrets() -> [ChordFretVariant] {
////        guard let grundton else { return [] }
////        
////        var res: [ChordFretVariant] = []
////        res.append(contentsOf: ChordGenerator.nonBarre(grundton: grundton, quality: quality, ext: ext, basston: basston))
////        res.append(contentsOf: ChordGenerator.barre(grundton: grundton, quality: quality, ext: ext, basston: basston))
////        res.append(contentsOf: ChordGenerator.movableChord(grundton: grundton, quality: quality, ext: ext, basston: basston))
////        return res.sorted { $0.base < $1.base }
////    }
//        
//    public static func parse(_ chordString: String, rootSystem: inout ChordRoot, strict: Bool) throws -> ParsedChord? {
//        if chordString.isEmpty { return nil }
//        
//        // Grundton
//        let str = chordString.lowercased()
//        let gtIndex: Int?
//        let grundtonLen: Int
//        let isFlat: Bool
//        (gtIndex, grundtonLen, isFlat) = findTone(tone: str, rootSystem: &rootSystem)
//        
//        if gtIndex == nil { return nil }
//        
//        var index = chordString.index(chordString.startIndex, offsetBy: grundtonLen)
//        
//        var quality: ChordQuality?
//        if index < chordString.endIndex && !String(chordString[index...]).lowercased().starts(with: "maj") {
//            quality = ChordQuality.allCases.first(where: { String(chordString[index...]).lowercased().starts(with: $0.rawValue) })
//            if let quality = quality {
//                index = chordString.index(index, offsetBy: quality.rawValue.count)
//            }
//        }
//        
//        try Task.checkCancellation()
//        
//        var ext: ChordExt?
//        if index < chordString.endIndex {
//            ext = ChordExt.allCases.first(where: { String(chordString[index...]).lowercased().starts(with: $0.rawValue) })
//            if let ext = ext {
//                index = chordString.index(index, offsetBy: ext.rawValue.count)
//            }
//        }
//        
//        try Task.checkCancellation()
//        
//        var bsIndex: Int?
//        var bassFlat: Bool = false
//        if index < chordString.endIndex && chordString[index] == "/" {
//            index = chordString.index(index, offsetBy: 1)
//            
//            if index < chordString.endIndex {
//                // Basston extrahieren
//                let bassLen: Int
//                let str = chordString[index...].lowercased()
//                (bsIndex, bassLen, bassFlat) = findTone(tone: str, rootSystem: &rootSystem)
//                index = chordString.index(index, offsetBy: bassLen)
//            }
//            if bsIndex == nil && strict { return nil }
//        }
//        
//        if index < chordString.endIndex && strict {
//            return nil
//        }
//        
//        return ParsedChord(name: chordString, grundton: gtIndex, isFlat: isFlat, quality: quality, ext: ext, basston: bsIndex, isBassFlat: bassFlat)
//    }
//    
//    /// Sucht einen Ton im Notationssystem, Ergebnis ist der Index
//    /// Dabei wird vermerkt, ob der Ton aus der sharp- oder flat-Liste ist.
//    /// Es wird der längste passende String gewählt (siehe shortTone: "as" und "asus" bedenken)
//    private static func findTone(tone: String, rootSystem: inout ChordRoot) -> (Int?, Int, isFlat: Bool) {
//        var idx = 0
//        var sharpIdx: Int?
//        var sharpLen = 0
//        var shortTone = tone.replacingOccurrences(of: "sus", with: "X")
//        shortTone = shortTone.replacingOccurrences(of: "add", with: "X")
//        shortTone = shortTone.replacingOccurrences(of: "maj", with: "X")
//        
//        for rootElem in rootSystem.sharps {
//            for enharmonic in rootElem {
//                if shortTone.starts(with: enharmonic) && enharmonic.count > sharpLen {
//                    sharpLen = enharmonic.count
//                    sharpIdx = idx
//                }
//            }
//            idx += 1
//        }
//        
//        var flatIdx: Int?
//        var flatLen = 0
//        idx = 0
//        for rootElem in rootSystem.flats {
//            for enharmonic in rootElem {
//                if shortTone.starts(with: enharmonic) && enharmonic.count > flatLen {
//                    flatLen = enharmonic.count
//                    flatIdx = idx
//                }
//            }
//            idx += 1
//        }
//        
//        return flatLen > sharpLen ? (flatIdx, flatLen, true) : (sharpIdx, sharpLen, false)
//    }
//    
//    public func toString(transpose: Int, rootSystem: inout ChordRoot) -> (String, ParsedChord?) {
//        if transpose != 0 {
//            let tChord = transposeChord(by: transpose, rootSystem: &rootSystem)
//            
//            if let tChord = tChord {
//                return (tChord.toString_(transpose: transpose, rootSystem: &rootSystem), tChord)
//            }
//            
//            return ("?", nil)
//        }
//        
//        return (toString_(transpose: transpose, rootSystem: &rootSystem), nil)
//    }
//    
//    private func toString_(transpose: Int, rootSystem: inout ChordRoot) -> String {
//        var res = ""
//                
//        if let grundton = grundton {
//            if transpose < 0 || isFlat {
//                res.append(rootSystem.flats[grundton].first!.capitalized)
//            } else {
//                res.append(rootSystem.sharps[grundton].first!.capitalized)
//            }
//        }
//        
//        if let quality = quality {
//            res.append(quality.rawValue)
//        }
//        
//        if let ext = ext {
//            res.append(ext.rawValue)
//        }
//        
//        if let basston = basston {
//            if transpose < 0 || isBassFlat {
//                res.append("/" + rootSystem.flats[basston].first!.capitalized)
//            } else {
//                res.append("/" + rootSystem.sharps[basston].first!.capitalized)
//            }
//        }
//        
//        return res
//    }
//    
//    private func transposeChord(by halfSteps: Int, rootSystem: inout ChordRoot) -> ParsedChord? {
//        let sharps = rootSystem.sharps
//        let flats = rootSystem.flats
//        
//        if let grundton = grundton {
//            let gTrx = transposeTone(tone: grundton, by: halfSteps)
//            
//            if let basston = basston {
//                let bTrx = transposeTone(tone: basston, by: halfSteps)
//                
//                return ParsedChord(name: name, grundton: gTrx, isFlat: isFlat, quality: quality, ext: ext, basston: bTrx, isBassFlat: isBassFlat)
//            }
//            
//            return ParsedChord(name: name, grundton: gTrx, isFlat: isFlat, quality: quality, ext: ext, basston: basston, isBassFlat: isBassFlat)
//        }
//        
//        return nil
//        
//        func transposeTone(tone: Int, by halfSteps: Int) -> Int {
//            let trx = halfSteps >= 0 ? sharps : flats
//            let transposeVal = if halfSteps >= 0 {
//                halfSteps % trx.count
//            } else {
//                -((-halfSteps) % trx.count)
//            }
//            
//            return (tone + transposeVal + trx.count) % (trx.count)
//        }
//    }
//    
//    static func mergeArrays(_ seq1: [[String]], _ seq2: [[String]]) -> [[String]] {
//        var merged: [[String]] = []
//        
//        for (seq1Group, seq2Group) in zip(seq1, seq2) {
//            // Kombiniere die Subarrays, behalte die Reihenfolge und entferne Duplikate
//            var combined = seq1Group
//            for element in seq2Group {
//                if !combined.contains(element) {
//                    combined.append(element)
//                }
//            }
//            merged.append(combined)
//        }
//        
//        return merged
//    }
//}

// ********************************   ChordII   *****************************************

public struct ChordFretVariant: Hashable, Equatable, Sendable {
    let base: Int       // fretoffset
    let frets: [Int]  // -1 = nicht spielen, 0 = offene Saite, 1-22 = Bund
    let fingers: [Int?]  // Finger, die die Saiten greifen (optional)
}

nonisolated
public struct TransposeParm: Sendable, Equatable, Hashable {
    let semitones: Int
    let fromKey: Key?
    let transposeKey: Bool      // simple oder Key-Transposition
}

nonisolated
enum ChordMode: Hashable {
    case major
    case minor
    case dim
    case aug
    
    func toString() -> String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .dim: return "dim"
        case .aug: return "aug"
        }
    }
}

// Structured chord extensions
nonisolated
enum ExtensionKind: Equatable, Sendable {
    case maj(Int)    // maj7, maj9, ...
    case add(Int)    // add9, add11, ...
    case sus(Int)    // sus2, sus4
    case flat(Int)   // b9
    case sharp(Int)  // #9
    case plain(Int)  // 7, 9, 11, 13
}

nonisolated
public struct ChordII: Identifiable, Equatable, Sendable {
    public let id = UUID()

    let note: Note          // Note
    private let noteStr: String     // unveränderter input String der Note
    private let noteExt: String     // alles nach erkannter Note: A#maj7: maj7
    let mode: ChordMode     // ChordMode
    private let modeStr: String     // unveränderter mode String: m, min ...
    private let bass: Note?         // evtl. Note für Bass
    private let bassStr: String?    // unveränderter input String der Bassnote
    private let bassExt: String?    // alles nach erkannter Bassnote, auch unsinniges
    private let extensions: [ExtensionKind] // parsed structured extensions
    
    private func extToString() -> String {
        if !extensions.isEmpty {
            let extStr = extensions.map { ext in
                switch ext {
                case .maj(let n): return "maj\(n)"
                case .add(let n): return "add\(n)"
                case .sus(let n): return n > 0 ? "sus\(n)" : "sus"
                case .flat(let n): return "b\(n)"
                case .sharp(let n): return "#\(n)"
                case .plain(let n): return "\(n)"
                }
            }.joined()
            return extStr
        }
        return ""
    }
    
    // ursprünglicher Text, wie beim parsen
    public func toString() -> String {
        return "\(noteStr)\(modeStr)\(noteExt)\(bass != nil ? "/" + (bassStr ?? "") + (bassExt ?? "") : "")"
    }
    
    // note und bass richten sich nach rootSys, der Rest ursprünglich
    public func toString(rootSys: RootSys) -> String {
        return "\(note.toString(rootSys: rootSys))\(modeStr)\(noteExt)\(bass != nil ? "/" + (bass?.toString(rootSys: rootSys) ?? "") + (bassExt ?? "") : "")"
    }
    
    // note und bass richten sich nach rootSys, zusätzlich Transponieren
    public func toString(rootSys: RootSys, transposeParm: TransposeParm?) -> (String, ChordII?) {
        if let transposeParm, transposeParm.semitones != 0 {
            let keySys = KeySystem()
            if let key = transposeParm.fromKey, transposeParm.transposeKey {
                guard let baseNote = keySys.transpose(from: key, note: note, by: transposeParm.semitones) else { return (toString(), self) }
                
                if let bass {
                    guard let bassNote = keySys.transpose(from: key, note: bass, by: transposeParm.semitones) else { return (toString(), self) }
                    let trxChord = ChordII(note: baseNote, noteStr: baseNote.toString(rootSys: rootSys), noteExt: noteExt, mode: mode, modeStr: modeStr, bass: bassNote, bassStr: bassNote.toString(rootSys: rootSys), bassExt: bassExt, extensions: self.extensions)
                    return (trxChord.toString(), trxChord)
                }
                
                let trxChord = ChordII(note: baseNote, noteStr: baseNote.toString(rootSys: rootSys), noteExt: noteExt, mode: mode, modeStr: modeStr, bass: nil, bassStr: nil, bassExt: nil, extensions: self.extensions)
                return (trxChord.toString(), trxChord)
            } else {
                let baseNote = keySys.transpose(note: note, by: transposeParm.semitones)
                
                if let bass {
                    let bassNote = keySys.transpose(note: bass, by: transposeParm.semitones)
                    let trxChord = ChordII(note: baseNote, noteStr: baseNote.toString(rootSys: rootSys), noteExt: noteExt, mode: mode, modeStr: modeStr, bass: bassNote, bassStr: bassNote.toString(rootSys: rootSys), bassExt: bassExt, extensions: self.extensions)
                    return (trxChord.toString(), trxChord)
                }
                
                let trxChord = ChordII(note: baseNote, noteStr: baseNote.toString(rootSys: rootSys), noteExt: noteExt, mode: mode, modeStr: modeStr, bass: nil, bassStr: nil, bassExt: nil, extensions: self.extensions)
                return (trxChord.toString(), trxChord)
            }
        }
        
        let chordStr = toString(rootSys: rootSys)
        return (chordStr, self)
    }
    
    public static func parse(_ input: String, preferedGermanParsing: Bool, strict: Bool) throws -> ChordII? {
        let parts = splitAtFirstSlash(input)
        
        if let (parsedNote, remainder) = ChordII.parseWithRemainder(from: parts.left, preferedGermanParsing: preferedGermanParsing) {
            try Task.checkCancellation()

            // Erkannten Notenstring als original-String merken. Dazu Remainder am Ende entfernen
            let n = min(parts.left.count, remainder.count)
            let endIndex = parts.left.index(parts.left.endIndex, offsetBy: -n)
            let noteStr = String(parts.left[..<endIndex])
            
            // ChordMode erkennen und in modeStr merken
            var consumed = 0
            var mode = ChordMode.major
            var modeStr = ""
            if remainder.hasPrefix("min") { mode = .minor; consumed += 3; modeStr = "min" }
            else if remainder.hasPrefix("maj") {  }
            else if remainder.hasPrefix("m") { mode = .minor; consumed += 1; modeStr = "m" }
            else if remainder.hasPrefix("aug") { mode = .aug; consumed += 3; modeStr = "aug" }
            else if remainder.hasPrefix("dim") { mode = .dim; consumed += 3; modeStr = "dim" }
            let rest = String(remainder.dropFirst(consumed))
            
            // Parse structured extensions from rest (e.g., maj7, add9, sus4, 7, 9, 11, 13). Allow multiple chained.
            let (exts, leftover) = ChordII.parseExtensions(from: rest)
            
            if strict && !leftover.isEmpty { return nil }

            // BassNote erkennen und in bassStr merken
            if !parts.right.isEmpty, let (bassNote, rest2) = ChordII.parseWithRemainder(from: parts.right, preferedGermanParsing: preferedGermanParsing) {
                try Task.checkCancellation()

                let n = min(parts.right.count, rest2.count)
                let endIndex = parts.right.index(parts.right.endIndex, offsetBy: -n)
                let bassStr = String(parts.right[..<endIndex])
                
                if strict && !rest2.isEmpty { return nil }
                return ChordII(note: parsedNote, noteStr: noteStr, noteExt: rest, mode: mode, modeStr: modeStr, bass: bassNote, bassStr: bassStr, bassExt: rest2, extensions: exts)
            }
            
            // keine BassNote
            return ChordII(note: parsedNote, noteStr: noteStr, noteExt: rest, mode: mode, modeStr: modeStr, bass: nil, bassStr: nil, bassExt: nil, extensions: exts)
        }
        
        // nix erkannt
        return nil
        
        func splitAtFirstSlash(_ s: String) -> (left: String, right: String) {
            guard let idx = s.firstIndex(of: "/") else { return (s, "") }
            let left = String(s[..<idx])
            let right = String(s[s.index(after: idx)...])
            return (left, right)
        }
    }
    
    private static func parseExtensions(from input: String) -> ([ExtensionKind], String) {
        if input.isEmpty { return ([], input) }
        
        var exts: [ExtensionKind] = []
        var idx = input.startIndex
        let s = input
        func consumePrefix(_ p: String) -> Bool {
            if s[idx...].hasPrefix(p) {
                idx = s.index(idx, offsetBy: p.count)
                return true
            }
            return false
        }
        func readNumber() -> Int? {
            var j = idx
            var val = 0
            var has = false
            while j < s.endIndex, let d = s[j].wholeNumberValue {
                has = true
                val = val * 10 + d
                j = s.index(after: j)
            }
            if has && val <= 13 && val != 0 && val != 1 && val != 8 && val != 10 && val != 12 { idx = j; return val } else { return nil }
        }
        // Loop to parse multiple extension tokens
        while idx < s.endIndex {
            // Skip separators like spaces or parentheses
            if s[idx] == " " || s[idx] == "(" || s[idx] == ")" { idx = s.index(after: idx); continue }
            let start = idx
            if consumePrefix("maj"), let n = readNumber() { exts.append(.maj(n)); continue }
            if consumePrefix("add"), let n = readNumber() { exts.append(.add(n)); continue }
            if consumePrefix("sus") { exts.append(.sus(readNumber() ?? 0)); continue }
            if consumePrefix("b"), let n = readNumber() { exts.append(.flat(n)); continue }
            if consumePrefix("#"), let n = readNumber() { exts.append(.sharp(n)); continue }
            if consumePrefix("^"), let n = readNumber() { exts.append(.maj(n)); continue }
            // plain numbers like 7, 9, 11, 13
            if let n = readNumber() { exts.append(.plain(n)); continue }
            // No known token; stop parsing
            idx = start
            break
        }
        let leftover = String(s[idx...])
        return (exts, leftover)
    }
    
    private static func parseWithRemainder(from input: String, preferedGermanParsing: Bool) -> (note: Note, remainder: String)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let origin = trimmed.lowercased()
        
        let splitted = splitAtFirstPrefix(str: trimmed, of: ["sus"])
        let lower = splitted?.before.lowercased() ?? origin
        
        var baseNat: NaturalNote?
        var germanB: Bool = false
        
        if let first = lower.first {
            if lower.hasPrefix("h") {
                baseNat = .B
            } else if lower.hasPrefix("b") && !lower.hasPrefix("bb") && !lower.hasPrefix("b#") && preferedGermanParsing {
                baseNat = .B
                germanB = true
            } else {
                baseNat = latinBase(first)
            }
        }
        
        guard let baseNat else { return nil }
        var acc: Accidental = .none
        
        let rest = String(lower.dropFirst())
        var consumed = 0
        if rest.hasPrefix("##") { acc = .doubleSharp; consumed = 2 }
        else if rest.hasPrefix("#") { acc = .sharp; consumed = 1 }
        else if rest.hasPrefix("bb") { acc = .doubleFlat; consumed = 2 }
        else if rest.hasPrefix("b") { acc = .flat; consumed = 1 }
        else { acc = .none; consumed = 0 }
        let remainder = String(origin.dropFirst(consumed+1))
        if consumed > 0 { return (Note(nat: baseNat, acc: germanB ? flattenAcc(acc): acc), remainder) }
        
        // German full-name map as prefix matching; find the longest matching key
        let germanMap: [String: (NaturalNote, Accidental)] = [
            "c": (.C, .none), "cis": (.C, .sharp), "ces": (.C, .flat), "cisis": (.C, .doubleSharp), "ceses": (.C, .doubleFlat),
            "d": (.D, .none), "dis": (.D, .sharp), "des": (.D, .flat), "disis": (.D, .doubleSharp), "deses": (.D, .doubleFlat),
            "e": (.E, .none), "eis": (.E, .sharp), "es": (.E, .flat), "ees": (.E, .flat), "eisis": (.E, .doubleSharp), "eses": (.E, .doubleFlat),
            "f": (.F, .none), "fis": (.F, .sharp), "fes": (.F, .flat), "fisis": (.F, .doubleSharp), "feses": (.F, .doubleFlat),
            "g": (.G, .none), "gis": (.G, .sharp), "ges": (.G, .flat), "gisis": (.G, .doubleSharp), "geses": (.G, .doubleFlat),
            "a": (.A, .none), "ais": (.A, .sharp), "as": (.A, .flat), "aes": (.A, .flat), "aisis": (.A, .doubleSharp), "ases": (.A, .doubleFlat),
            "h": (.B, .none), "his": (.B, .sharp), "hes": (.B, .flat), "hisis": (.B, .doubleSharp), "heses": (.B, .doubleFlat),
            "b": (.B, preferedGermanParsing ? .flat : .none), "bis": (.B, .none), "bes": (.B, .doubleFlat)
        ]
        
        // Longest prefix match
        var best: (String, (NaturalNote, Accidental))?
        for (k, v) in germanMap {
            if lower.hasPrefix(k) {
                if best == nil || k.count > best!.0.count { best = (k, v) }
            }
        }
        if let (prefix, pair) = best {
            let remainder = String(origin.dropFirst(prefix.count))
            return (Note(nat: pair.0, acc: pair.1), remainder)
        }
        
        return nil
        
        func flattenAcc(_ accidental: Accidental) -> Accidental {
            var acc = accidental.rawValue
            if acc > Accidental.doubleFlat.rawValue { acc -= 1 }
            return Accidental(rawValue: acc)!
        }
        
        func latinBase(_ ch: Character) -> NaturalNote? {
            switch ch {
            case "c": return .C
            case "d": return .D
            case "e": return .E
            case "f": return .F
            case "g": return .G
            case "a": return .A
            case "b": return .B
            default: return nil
            }
        }
        
        func splitAtFirstPrefix(str: String, of prefixes: [String]) -> (before: String, atPrefix: String, after: String)? {
            // Wir arbeiten auf lowercase für robusten Vergleich, behalten aber die Original-Slices bei.
            let lower = str.lowercased()
            var bestRange: Range<String.Index>?
            var bestPrefix: String?
            
            // Suche irgendwo im String:
            for p in prefixes {
                if let r = lower.range(of: p) {
                    if let currentBest = bestRange {
                        if r.lowerBound < currentBest.lowerBound {
                            bestRange = r
                            bestPrefix = p
                        }
                    } else {
                        bestRange = r
                        bestPrefix = p
                    }
                }
            }
            
            guard let range = bestRange, let _ = bestPrefix else { return nil }
            let before = String(str[..<range.lowerBound])
            let atPrefix = String(str[range.lowerBound..<range.upperBound]) // z.B. "maj", "add", "sus"
            let after = String(str[range.upperBound...]) // z.B. "7", "2", "9"
            return (before, atPrefix, after)
        }
    }
    
    func getFrets() -> [ChordFretVariant] {
        var res: [ChordFretVariant] = []
        res.append(contentsOf: ChordGenerator.nonBarre(grundton: note.semitone, mode: mode, ext: extensions, basston: bass?.semitone ?? nil))
        res.append(contentsOf: ChordGenerator.barre(grundton: note.semitone, mode: mode, ext: extensions, basston: bass?.semitone ?? nil))
        res.append(contentsOf: ChordGenerator.movableChord(grundton: note.semitone, mode: mode, ext: extensions, basston: bass?.semitone ?? nil))
        return res.sorted { $0.base < $1.base }
    }
}

nonisolated
public enum RootSys: Sendable {
    case common
    case german
}

nonisolated
enum NaturalNote: String, CaseIterable {
    case C, D, E, F, G, A, B
    
    var semitone: Int {
        switch self {
        case .C: 0
        case .D: 2
        case .E: 4
        case .F: 5
        case .G: 7
        case .A: 9
        case .B: 11
        }
    }
}

nonisolated
enum Accidental: Int {
    case doubleFlat = -2
    case flat = -1
    case none = 0
    case sharp = 1
    case doubleSharp = 2
    
    func toString() -> String {
        switch self {
        case .none: return ""
        case .sharp: return "#"
        case .doubleSharp: return "##"
        case .flat: return "b"
        case .doubleFlat: return "bb"
        }
    }
}

nonisolated
struct Note: Equatable, Hashable {
    let nat: NaturalNote
    let acc: Accidental
        
    func toString(rootSys: RootSys) -> String {
        switch rootSys {
        case .common: return "\(nat.rawValue)\(acc.toString())"
        case .german: return toGerman()
        }
    }
    
    func toGerman() -> String {
        switch (nat, acc) {
        case (.B, .none): return "H"
        case (.B, .flat): return "B"
        case (.B, .sharp): return "His"
        case (.B, .doubleFlat): return "Heses"
        case (.B, .doubleSharp): return "Hisis"
        case (let n, .none): return n.rawValue
        case (.C, .flat): return "Ces"
        case (.C, .sharp): return "Cis"
        case (.C, .doubleFlat): return "Ceses"
        case (.C, .doubleSharp): return "Cisis"
        case (.D, .flat): return "Des"
        case (.D, .sharp): return "Dis"
        case (.D, .doubleFlat): return "Deses"
        case (.D, .doubleSharp): return "Disis"
        case (.E, .flat): return "Es"
        case (.E, .sharp): return "Eis"
        case (.E, .doubleFlat): return "Eses"
        case (.E, .doubleSharp): return "Eisis"
        case (.F, .flat): return "Fes"
        case (.F, .sharp): return "Fis"
        case (.F, .doubleFlat): return "Feses"
        case (.F, .doubleSharp): return "Fisis"
        case (.G, .flat): return "Ges"
        case (.G, .sharp): return "Gis"
        case (.G, .doubleFlat): return "Geses"
        case (.G, .doubleSharp): return "Gisis"
        case (.A, .flat): return "As"
        case (.A, .sharp): return "Ais"
        case (.A, .doubleFlat): return "Ases"
        case (.A, .doubleSharp): return "Aisis"
        }
    }
    
    var semitone: Int { return (nat.semitone + acc.rawValue + 12) % 12 }
}

nonisolated
enum Mode: Hashable {
    case major
    case minor
    
    func toString() -> String {
        "\(self == .major ? "" : "m")"
    }
}

nonisolated
struct Key: Hashable {
    let note: Note
    let mode: Mode
    
    func toString(rootSys: RootSys) -> String {
        "\(note.toString(rootSys: rootSys))\(mode.toString())"
    }
}

nonisolated
struct KeySystem {
    func toString() -> String {
        var res: String = ""
        for k in KeySystem.keys.keys.sorted(by: {$0.note.semitone < $1.note.semitone }) {
            let semitones = k.note.semitone
            let keyString = k.toString(rootSys: .common)
            
            res += "\(keyString) \(semitones)\n"
        }
        return res
    }
    
    func keyToString(key: Key) -> String {
        if let k = KeySystem.keys[key] {
            return "\(key.toString(rootSys: .common)) -> \(k.map { $0.toString(rootSys: .common) }.joined(separator: ", "))"
        }
        return ""
    }
    
    /// Build a semitone-to-Note spelling map from the given key's scale.
    private func spellingMap(for key: Key) -> [Int: Note] {
        guard let scale = KeySystem.keys[key] else { return [:] }
        var map: [Int: Note] = [:]
        for n in scale {
            let s = (n.nat.semitone + n.acc.rawValue + 12) % 12
            map[s] = n
        }
        return map
    }
    
    private func preferSharps(key: Key) -> Bool {
        switch (key.note.nat, key.note.acc) {
        case (.C, .none), (.D, .none), (.E, .none), (.F, .none), (.G, .none), (.A, .none), (.B, .none): return true
        case (_, .sharp): return true
        default: return false
        }
    }
    
    /// Choose a destination key by tonic semitone and a preferred accidental world.
    /// Tries to find a key in the known directory whose tonic matches and whose spelling matches the preference.
    /// Falls back to any matching tonic if preference isn't available.
    private func keyForTonic(semitone: Int, fromAcc: Accidental, preferSharps: Bool, mode: Mode) -> Key? {
        // Gather candidates that match tonic semitone
        // Sortiert nach fromAcc: Elemente mit gleichem fromAcc kommen zuerst.
        
        let sharps = KeySystem.keys.keys.filter { k in
            let s = (k.note.semitone + 12) % 12
            return s == ((semitone % 12) + 12) % 12 && k.mode == mode && k.note.acc == Accidental.sharp
        }
        let flats = KeySystem.keys.keys.filter { k in
            let s = (k.note.semitone + 12) % 12
            return s == ((semitone % 12) + 12) % 12 && k.mode == mode && k.note.acc == Accidental.flat
        }
        let nones = KeySystem.keys.keys.filter { k in
            let s = (k.note.semitone + 12) % 12
            return s == ((semitone % 12) + 12) % 12 && k.mode == mode && k.note.acc == Accidental.none
        }
        let doubleSharps = KeySystem.keys.keys.filter { k in
            let s = (k.note.semitone + 12) % 12
            return s == ((semitone % 12) + 12) % 12 && k.mode == mode && k.note.acc == Accidental.doubleSharp
        }
        let doubleflats = KeySystem.keys.keys.filter { k in
            let s = (k.note.semitone + 12) % 12
            return s == ((semitone % 12) + 12) % 12 && k.mode == mode && k.note.acc == Accidental.doubleFlat
        }

        // Order candidate keys based on the source accidental to keep spelling stable
        let ordered: [Key] = {
            switch fromAcc {
            case .doubleFlat:
                return doubleflats + flats + nones + sharps + doubleSharps
            case .flat:
                return flats + nones + sharps + doubleSharps + doubleflats
            case .none:
                return nones + sharps + flats + doubleSharps + doubleflats
            case .sharp:
                return sharps + nones + flats + doubleSharps + doubleflats
            case .doubleSharp:
                return doubleSharps + sharps + nones + flats + doubleflats
            }
        }()

        if ordered.isEmpty { return nil }
        return ordered.first
    }
    
    /// Simple chromatic transposition independent of key spelling.
    /// Positive semitone offsets prefer sharp spellings, negative prefer flat spellings.
    /// - Parameters:
    ///   - note: Source note to transpose
    ///   - semitones: Semitone offset (can be negative)
    /// - Returns: Transposed note using global chromatic names
    func transpose(note: Note, by semitones: Int) -> Note {
        let src = note.semitone
        let dst = (src + (semitones % 12) + 12) % 12
        let names = semitones >= 0 ? KeySystem.sharpNames : KeySystem.flatNames
        return names[dst]
    } // ADDED
    
    /// Transpose a note from a source key to a destination key, preserving scale degree where possible.
    /// - Parameters:
    ///   - from: Source key (tonality providing the context of the input note)
    ///   - to: Destination key to transpose into
    ///   - note: The note (spelled) to transpose from the source key
    /// - Returns: The transposed note spelled according to the destination key where possible
    func transpose(from: Key, to: Key, note: Note) -> Note? {
        // Compute semitone distance between tonic of source and destination
        let srcTonic = from.note.semitone
        let dstTonic = to.note.semitone
        let rel = (note.semitone - srcTonic + 12) % 12
        let dstSemitone = (dstTonic + rel) % 12
        
        // 1) Try to spell using the destination key's scale
        let map = spellingMap(for: to)
        if let spelled = map[dstSemitone] {
            return spelled
        }
        
        // 2) Fallback: use global chromatic names based on a heuristic preference
        let names = preferSharps(key: to) ? KeySystem.sharpNames : KeySystem.flatNames
        return names[dstSemitone]
    }
    
    /// Transpose a note by a semitone offset within the context of a destination key's spelling.
    /// - Parameters:
    ///   - to: Destination key used only for spelling (accidentals) of the result
    ///   - note: The source note to transpose
    ///   - toSemitones: Positive or negative semitone offset
    /// - Returns: The transposed note spelled according to the destination key where possible
    func transpose(to toKey: Key, note: Note, by toSemitones: Int) -> Note? {
        let src = note.semitone
        let dstSemitone = (src + toSemitones % 12 + 12) % 12
        
        // 1) Try destination key spelling first
        let map = spellingMap(for: toKey)
        if let spelled = map[dstSemitone] {
            return spelled
        }
        
        // 2) Fallback to global names
        let names = preferSharps(key: toKey) ? KeySystem.sharpNames : KeySystem.flatNames
        return names[dstSemitone]
    }
    
    /// Transpose a note where the destination key is derived by shifting the source key's tonic by a semitone offset.
    /// - Parameters:
    ///   - from: Source key
    ///   - note: Note to transpose
    ///   - semitones: Semitone offset to apply to the source key's tonic to form the destination key (mode is preserved)
    /// - Returns: Transposed note spelled according to the derived destination key
    func transpose(from: Key, note: Note, by semitones: Int) -> Note? {
        let srcTonic = from.note.semitone
        let dstTonic = (srcTonic + semitones % 12 + 12) % 12
        let toPrefersSharps = preferSharps(key: from)
        
        if let derivedTo = keyForTonic(semitone: dstTonic, fromAcc: from.note.acc, preferSharps: toPrefersSharps, mode: from.mode) {
            return transpose(to: derivedTo, note: note, by: semitones)
        }

        // Fallback: derive tonic spelling from chromatic arrays as before
        let names = toPrefersSharps ? KeySystem.sharpNames : KeySystem.flatNames
        let dstNote = names[dstTonic]
        let derivedTo = Key(note: dstNote, mode: from.mode)
        return transpose(to: derivedTo, note: note, by: semitones)
    }
}

nonisolated
extension KeySystem {
    private static let majorInterval: [Int] = [2, 2, 1, 2, 2, 2, 1]
    private static let minorInterval: [Int] = [2, 1, 2, 2, 1, 2, 2]

    // Chromatic names in both spellings
    private static let sharpNames = [Note(nat: .C, acc: .none), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .none), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .none), Note(nat: .F, acc: .none), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .none), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .none), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .none)]
    private static let flatNames  = [Note(nat: .C, acc: .none), Note(nat: .D, acc: .flat), Note(nat: .D, acc: .none), Note(nat: .E, acc: .flat), Note(nat: .E, acc: .none), Note(nat: .F, acc: .none), Note(nat: .G, acc: .flat), Note(nat: .G, acc: .none), Note(nat: .A, acc: .flat), Note(nat: .A, acc: .none), Note(nat: .B, acc: .flat), Note(nat: .B, acc: .none)]

    private static let keys: [Key : [Note]] = [
        // Major keys
        // C
        Key(note: Note(nat: .C, acc: .none), mode: .major): [ .C, .D, .E, .F, .G, .A, .B ].map { Note(nat: $0, acc: .none) },
        // D
        Key(note: Note(nat: .D, acc: .none), mode: .major): [ Note(nat: .D, acc: .none), Note(nat: .E, acc: .none), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .none), Note(nat: .A, acc: .none), Note(nat: .B, acc: .none), Note(nat: .C, acc: .sharp) ],
        // E
        Key(note: Note(nat: .E, acc: .none), mode: .major): [ Note(nat: .E, acc: .none), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .none), Note(nat: .B, acc: .none), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .sharp) ],
        // F
        Key(note: Note(nat: .F, acc: .none), mode: .major): [ Note(nat: .F, acc: .none), Note(nat: .G, acc: .none), Note(nat: .A, acc: .none), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .none), Note(nat: .E, acc: .none) ],
        // G
        Key(note: Note(nat: .G, acc: .none), mode: .major): [ Note(nat: .G, acc: .none), Note(nat: .A, acc: .none), Note(nat: .B, acc: .none), Note(nat: .C, acc: .none), Note(nat: .D, acc: .none), Note(nat: .E, acc: .none), Note(nat: .F, acc: .sharp) ],
        // A
        Key(note: Note(nat: .A, acc: .none), mode: .major): [ Note(nat: .A, acc: .none), Note(nat: .B, acc: .none), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .none), Note(nat: .E, acc: .none), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .sharp) ],
        // B
        Key(note: Note(nat: .B, acc: .none), mode: .major): [ Note(nat: .B, acc: .none), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .none), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .sharp) ],

        // Major sharp keys
        // C#
        Key(note: Note(nat: .C, acc: .sharp), mode: .major): [ Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .sharp) ],
        // F#
        Key(note: Note(nat: .F, acc: .sharp), mode: .major): [ Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .none), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .sharp) ],
        
        // Major flat keys
        // Cb
        Key(note: Note(nat: .C, acc: .flat), mode: .major): [ Note(nat: .C, acc: .flat), Note(nat: .D, acc: .flat), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .flat), Note(nat: .G, acc: .flat), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .flat) ],
        // Db
        Key(note: Note(nat: .D, acc: .flat), mode: .major): [ Note(nat: .D, acc: .flat), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none), Note(nat: .G, acc: .flat), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none) ],
        // Eb
        Key(note: Note(nat: .E, acc: .flat), mode: .major): [ Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none), Note(nat: .G, acc: .none), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .none) ],
        // Gb
        Key(note: Note(nat: .G, acc: .flat), mode: .major): [ Note(nat: .G, acc: .flat), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .flat), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none) ],
        // Ab
        Key(note: Note(nat: .A, acc: .flat), mode: .major): [ Note(nat: .A, acc: .flat), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .flat), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none), Note(nat: .G, acc: .none) ],
        // Bb
        Key(note: Note(nat: .B, acc: .flat), mode: .major): [ Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .none), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none), Note(nat: .G, acc: .none), Note(nat: .A, acc: .none) ],

        // Natural minor (aeolian) keys
        // Cm
        Key(note: Note(nat: .C, acc: .none), mode: .minor): [ Note(nat: .C, acc: .none), Note(nat: .D, acc: .none), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none), Note(nat: .G, acc: .none), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .flat) ],
        // Dm
        Key(note: Note(nat: .D, acc: .none), mode: .minor): [ Note(nat: .D, acc: .none), Note(nat: .E, acc: .none), Note(nat: .F, acc: .none), Note(nat: .G, acc: .none), Note(nat: .A, acc: .none), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none) ],
        // Em
        Key(note: Note(nat: .E, acc: .none), mode: .minor): [ Note(nat: .E, acc: .none), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .none), Note(nat: .A, acc: .none), Note(nat: .B, acc: .none), Note(nat: .C, acc: .none), Note(nat: .D, acc: .none) ],
        // Fm
        Key(note: Note(nat: .F, acc: .none), mode: .minor): [ Note(nat: .F, acc: .none), Note(nat: .G, acc: .none), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .flat), Note(nat: .E, acc: .flat) ],
        // Gm
        Key(note: Note(nat: .G, acc: .none), mode: .minor): [ Note(nat: .G, acc: .none), Note(nat: .A, acc: .none), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .none), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none) ],
        // Am
        Key(note: Note(nat: .A, acc: .none), mode: .minor): [ .A, .B, .C, .D, .E, .F, .G ].map { Note(nat: $0, acc: .none) },
        // Bm
        Key(note: Note(nat: .B, acc: .none), mode: .minor): [ Note(nat: .B, acc: .none), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .none), Note(nat: .E, acc: .none), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .none), Note(nat: .A, acc: .none) ],

        // Minor sharp keys
        // C#m
        Key(note: Note(nat: .C, acc: .sharp), mode: .minor): [ Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .none), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .none), Note(nat: .B, acc: .none) ],
        // D#m
        Key(note: Note(nat: .D, acc: .sharp), mode: .minor): [ Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .none), Note(nat: .C, acc: .sharp) ],
        // F#m
        Key(note: Note(nat: .F, acc: .sharp), mode: .minor): [ Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .none), Note(nat: .B, acc: .none), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .none), Note(nat: .E, acc: .none) ],
        // G#m
        Key(note: Note(nat: .G, acc: .sharp), mode: .minor): [ Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .none), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .none), Note(nat: .F, acc: .sharp) ],
        // A#m (enharmonic to Bbm)
        Key(note: Note(nat: .A, acc: .sharp), mode: .minor): [ Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .sharp), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .sharp), Note(nat: .G, acc: .sharp) ],
        
        // Minor flat keys
        // Ebm
        Key(note: Note(nat: .E, acc: .flat), mode: .minor): [ Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none), Note(nat: .G, acc: .flat), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .flat) ],
        // Abm
        Key(note: Note(nat: .A, acc: .flat), mode: .minor): [ Note(nat: .A, acc: .flat), Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .flat), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none), Note(nat: .G, acc: .flat) ],
        // Bbm
        Key(note: Note(nat: .B, acc: .flat), mode: .minor): [ Note(nat: .B, acc: .flat), Note(nat: .C, acc: .none), Note(nat: .D, acc: .flat), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .none), Note(nat: .G, acc: .flat), Note(nat: .A, acc: .flat) ],
        
        // Theoretical / rare major keys
        // D#
        Key(note: Note(nat: .D, acc: .sharp), mode: .major): [ Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .doubleSharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .sharp), Note(nat: .C, acc: .doubleSharp) ],
        // E#
        Key(note: Note(nat: .E, acc: .sharp), mode: .major): [ Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .doubleSharp), Note(nat: .G, acc: .doubleSharp), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .sharp), Note(nat: .C, acc: .doubleSharp), Note(nat: .D, acc: .doubleSharp) ],
        // Fb
        Key(note: Note(nat: .F, acc: .flat), mode: .major): [ Note(nat: .F, acc: .flat), Note(nat: .G, acc: .flat), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .doubleFlat), Note(nat: .C, acc: .flat), Note(nat: .D, acc: .flat), Note(nat: .E, acc: .flat) ],
        // G#
        Key(note: Note(nat: .G, acc: .sharp), mode: .major): [ Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .sharp), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .doubleSharp) ],
        // A#
        Key(note: Note(nat: .A, acc: .sharp), mode: .major): [ Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .sharp), Note(nat: .C, acc: .doubleSharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .doubleSharp), Note(nat: .G, acc: .doubleSharp) ],
        // B#
        Key(note: Note(nat: .B, acc: .sharp), mode: .major): [ Note(nat: .B, acc: .sharp), Note(nat: .C, acc: .doubleSharp), Note(nat: .D, acc: .doubleSharp), Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .doubleSharp), Note(nat: .G, acc: .doubleSharp), Note(nat: .A, acc: .doubleSharp) ],

        // Theoretical / rare natural minor keys
        // Cbm
        Key(note: Note(nat: .C, acc: .flat), mode: .minor): [ Note(nat: .C, acc: .flat), Note(nat: .D, acc: .flat), Note(nat: .E, acc: .doubleFlat), Note(nat: .F, acc: .flat), Note(nat: .G, acc: .flat), Note(nat: .A, acc: .doubleFlat), Note(nat: .B, acc: .doubleFlat) ],
        // Dbm
        Key(note: Note(nat: .D, acc: .flat), mode: .minor): [ Note(nat: .D, acc: .flat), Note(nat: .E, acc: .flat), Note(nat: .F, acc: .flat), Note(nat: .G, acc: .flat), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .doubleFlat), Note(nat: .C, acc: .flat) ],
        // E#m
        Key(note: Note(nat: .E, acc: .sharp), mode: .minor): [ Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .doubleSharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .sharp), Note(nat: .C, acc: .sharp), Note(nat: .D, acc: .sharp) ],
        // F##m
        Key(note: Note(nat: .F, acc: .doubleSharp), mode: .minor): [ Note(nat: .F, acc: .doubleSharp), Note(nat: .G, acc: .doubleSharp), Note(nat: .A, acc: .sharp), Note(nat: .B, acc: .sharp), Note(nat: .C, acc: .doubleSharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .sharp) ],
        // Fbm
        Key(note: Note(nat: .F, acc: .flat), mode: .minor): [ Note(nat: .F, acc: .flat), Note(nat: .G, acc: .flat), Note(nat: .A, acc: .doubleFlat), Note(nat: .B, acc: .doubleFlat), Note(nat: .C, acc: .flat), Note(nat: .D, acc: .doubleFlat), Note(nat: .E, acc: .doubleFlat) ],
        // Gbm
        Key(note: Note(nat: .G, acc: .flat), mode: .minor): [ Note(nat: .G, acc: .flat), Note(nat: .A, acc: .flat), Note(nat: .B, acc: .doubleFlat), Note(nat: .C, acc: .flat), Note(nat: .D, acc: .flat), Note(nat: .E, acc: .doubleFlat), Note(nat: .F, acc: .flat) ],
        // B#m
        Key(note: Note(nat: .B, acc: .sharp), mode: .minor): [ Note(nat: .B, acc: .sharp), Note(nat: .C, acc: .doubleSharp), Note(nat: .D, acc: .sharp), Note(nat: .E, acc: .sharp), Note(nat: .F, acc: .doubleSharp), Note(nat: .G, acc: .sharp), Note(nat: .A, acc: .sharp) ],
    ]
}

